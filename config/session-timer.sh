#!/bin/bash
#
# session-timer — Display session elapsed time in the XFCE panel.
#
# --init: record session start time (called from autostart .desktop).
# --check: output elapsed time for genmon plugin.

set -euo pipefail

STATE_FILE="${XDG_CACHE_HOME:-$HOME/.cache}/session-start"

if [ "${1-}" = "--init" ]; then
    mkdir -p "$(dirname "$STATE_FILE")"
    date +%s > "$STATE_FILE"
    exit 0
fi

if [ ! -f "$STATE_FILE" ]; then
    echo "⏱ --"
    exit 0
fi

start=$(cat "$STATE_FILE" 2>/dev/null || echo 0)
[ "$start" -gt 0 ] 2>/dev/null || { echo "⏱ --"; exit 0; }

now=$(date +%s)
elapsed=$((now - start))

days=$((elapsed / 86400))
hours=$(( (elapsed % 86400) / 3600 ))
mins=$(( (elapsed % 3600) / 60 ))

if [ "$days" -gt 0 ]; then
    printf "⏱ %dd %dh %dm\n" "$days" "$hours" "$mins"
elif [ "$hours" -gt 0 ]; then
    printf "⏱ %dh %dm\n" "$hours" "$mins"
else
    printf "⏱ %dm\n" "$mins"
fi
