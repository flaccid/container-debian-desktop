#!/bin/bash
# memmon — XFCE panel genmon widget for cgroup-aware memory usage.
# Shows pod memory (used/limit) instead of host memory.

set -euo pipefail

LIMIT_FILE="/sys/fs/cgroup/memory.max"
CURRENT_FILE="/sys/fs/cgroup/memory.current"

if [ ! -r "$LIMIT_FILE" ] || [ ! -r "$CURRENT_FILE" ]; then
    echo "N/A"
    exit 0
fi

read -r mem_limit < "$LIMIT_FILE"
read -r mem_current < "$CURRENT_FILE"

if [ "$mem_limit" = "max" ] || [ -z "$mem_limit" ] || [ "$mem_limit" -le 0 ] 2>/dev/null; then
    echo "N/A"
    exit 0
fi

pct=$((mem_current * 100 / mem_limit))

fmt_gib() {
    local val=$1
    local gib
    gib=$(echo "scale=1; $val / 1073741824" | bc -l 2>/dev/null || echo "0")
    printf "%.1fG" "$gib"
}

used=$(fmt_gib "$mem_current")
total=$(fmt_gib "$mem_limit")

if [ "$pct" -lt 50 ]; then
    color="#8ae234"
elif [ "$pct" -lt 80 ]; then
    color="#fce94f"
else
    color="#ef2929"
fi

printf '<span color="%s">🖥 %s/%s</span>\n' "$color" "$used" "$total"
