DOCKER_REGISTRY = index.docker.io
IMAGE_NAME = debian-desktop
IMAGE_VERSION = 0.9.0
IMAGE_ORG = flaccid
IMAGE_TAG = $(DOCKER_REGISTRY)/$(IMAGE_ORG)/$(IMAGE_NAME):$(IMAGE_VERSION)
KUBE_NAMESPACE = default

WORKING_DIR := $(shell pwd)

.DEFAULT_GOAL := help

.PHONY: build

docker-release:: docker-build docker-push ## Builds and pushes the docker image to the registry

docker-push:: ## Pushes the docker image to the registry
		@docker push $(IMAGE_TAG)

docker-build:: ## builds the docker image locally
		@docker build  \
			--pull \
			--build-arg GIT_INFO="$(shell git log -1 --pretty=format:'%h %s (%ci)')" \
			-t $(IMAGE_TAG) \
				$(WORKING_DIR)

docker-build-clean:: ## cleanly builds the docker image locally
		@docker build  \
			--no-cache \
			--pull \
			--build-arg GIT_INFO="$(shell git log -1 --pretty=format:'%h %s (%ci)')" \
			-t $(IMAGE_TAG) \
				$(WORKING_DIR)

docker-pull:: ## pulls the docker image locally
		@docker pull $(IMAGE_TAG)

docker-run:: ## Runs the docker image
		docker run \
			--name debian-desktop \
			-it \
			--rm \
			-p 6901:6901 \
			-p 6902:6902 \
			$(OPTS) \
				$(IMAGE_TAG) $(ARGS)

docker-exec-shell:: ## Executes a shell in running container
		@docker exec \
			-it \
				debian-desktop /bin/bash

docker-run-shell:: ## Runs the docker image with bash as entrypoint
		@docker run \
			-it \
			--entrypoint /bin/sh \
				$(IMAGE_TAG)

docker-rm:: ## Removes the running docker container
		@docker rm -f debian-desktop

docker-test:: ## tests the runtime of the docker image in a basic sense
		@docker run $(IMAGE_TAG) debian-desktop --version

helm-install:: ## installs using helm from chart in repo
		@helm install \
			-f helm-values.yaml \
			--namespace $(KUBE_NAMESPACE) \
				debian-desktop ./charts/debian-desktop

helm-upgrade:: ## upgrades deployed helm release
		@helm upgrade \
			-f helm-values.yaml \
			--namespace $(KUBE_NAMESPACE) \
				debian-desktop ./charts/debian-desktop

helm-uninstall:: ## deletes and purges deployed helm release
		@helm uninstall \
			--namespace $(KUBE_NAMESPACE) \
				debian-desktop

helm-reinstall:: helm-uninstall helm-install ## Uninstalls the helm release, then installs it again

helm-render:: ## prints out the rendered chart
		@helm install \
			-f helm-values.yaml \
			--namespace $(KUBE_NAMESPACE) \
			--dry-run \
			--debug \
				debian-desktop ./charts/debian-desktop

helm-validate:: ## runs a lint on the helm chart
		@helm lint \
			-f helm-values.yaml \
			--namespace $(KUBE_NAMESPACE) \
				charts/debian-desktop

helm-package:: ## packages the helm chart into an archive
		@helm package charts/debian-desktop

helm-index:: ## creates/updates the helm repo index file
		@helm repo index --url https://flaccid.github.io/container-debian-desktop/ .

helm-flush:: ## removes local helm packages and index file
		@rm -f ./debian-desktop-*.tgz
		@rm -f index.yaml

test:: test-structure test-bats test-smoke test-helm ## runs all tests

test-structure:: ## runs container structure tests against the local image
		@echo "Running container structure tests..."
		@curl -fsSL https://github.com/GoogleContainerTools/container-structure-test/releases/download/v1.22.1/container-structure-test-linux-amd64 -o /tmp/container-structure-test \
			&& chmod +x /tmp/container-structure-test \
			&& /tmp/container-structure-test test --image $(IMAGE_TAG) --config tests/container-structure-test.yaml

test-bats:: ## runs shell script tests with bats
		@echo "Running bats tests..."
		@command -v bats >/dev/null 2>&1 || { echo "Installing bats..."; sudo apt-get update -qq && sudo apt-get install -y -qq bats; }
		@bats tests/entrypoint.bats tests/reset-xfce4.bats tests/start-desktop.bats

test-smoke:: ## runs runtime smoke test against the local image
		@echo "Running smoke test..."
		@tests/smoke-test.sh $(IMAGE_TAG)

test-helm:: ## runs helm lint
		@echo "Running helm lint..."
		$(MAKE) helm-validate

# A help target including self-documenting targets (see the awk statement)
define HELP_TEXT
Usage: make [TARGET]... [MAKEVAR1=SOMETHING]...

Available targets:
endef
export HELP_TEXT
help: ## This help target
	@cat .banner
	@echo
	@echo "$$HELP_TEXT"
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / \
		{printf "\033[36m%-30s\033[0m  %s\n", $$1, $$2}' $(MAKEFILE_LIST)