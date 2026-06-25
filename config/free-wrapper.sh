#!/bin/bash
# cgroup-aware free — shows the container's memory limit (from cgroup v2)
# instead of the host's total memory. Falls through to the real free if
# cgroup limits are not available or for unrecognized flags.

set -euo pipefail

REAL_FREE=$(command -v free)

# Determine display scale from flags
scale=1024
unit="K"
format_k="%'d"
if [ $# -eq 0 ]; then
    set -- -k
fi

# Collect flags; after -- or a non-flag arg, pass through to real free
passthrough=false
args=()
for arg in "$@"; do
    if $passthrough; then
        exec "$REAL_FREE" "$@"
    fi
    case "$arg" in
        --)
            passthrough=true
            ;;
        --kilo|-k)
            scale=1024; unit="K"; format_k="%'d"
            ;;
        --mega|-m)
            scale=$((1024*1024)); unit="M"; format_k="%'d"
            ;;
        --giga|-g)
            scale=$((1024*1024*1024)); unit="G"; format_k="%'.1f"
            ;;
        --human|-h)
            scale=1; unit=""; format_k=""
            human=true
            ;;
        --tera|-t)
            scale=$((1024*1024*1024*1024)); unit="T"; format_k="%'.1f"
            ;;
        --wide|-w)
            # ignore, just pass through format
            ;;
        --si)
            scale=1000
            ;;
        -[0-9]*)
            # unrecognized flag, passthrough
            exec "$REAL_FREE" "$@"
            ;;
        -*)
            # unrecognized flag, passthrough
            exec "$REAL_FREE" "$@"
            ;;
        *)
            # non-flag arg, passthrough
            exec "$REAL_FREE" "$@"
            ;;
    esac
done

# Read cgroup v2 memory limit
MEM_LIMIT=""
if [ -r /sys/fs/cgroup/memory.max ]; then
    read -r raw < /sys/fs/cgroup/memory.max
    if [ "$raw" != "max" ] && [ -n "$raw" ] && [ "$raw" -gt 0 ] 2>/dev/null; then
        MEM_LIMIT=$raw
    fi
fi

# Fallback to cgroup v1
if [ -z "$MEM_LIMIT" ] && [ -r /sys/fs/cgroup/memory/memory.limit_in_bytes ]; then
    read -r raw < /sys/fs/cgroup/memory/memory.limit_in_bytes
    if [ -n "$raw" ] && [ "$raw" != "9223372036854771712" ] && [ "$raw" -gt 0 ] 2>/dev/null; then
        MEM_LIMIT=$raw
    fi
fi

# If no cgroup limit, fall through to real free
if [ -z "$MEM_LIMIT" ]; then
    exec "$REAL_FREE" "$@"
fi

# Read /proc/meminfo fields
read_meminfo() {
    awk -v key="$1" '$1 == key":" { print $2; exit }' /proc/meminfo 2>/dev/null || echo 0
}

mem_total_kb=$((MEM_LIMIT / 1024))
mem_free_kb=$(read_meminfo MemFree)
mem_available_kb=$(read_meminfo MemAvailable)
buffers_kb=$(read_meminfo Buffers)
cached_kb=$(read_meminfo Cached)
swap_cached_kb=$(read_meminfo SwapCached)
swap_total_kb=$(read_meminfo SwapTotal)
swap_free_kb=$(read_meminfo SwapFree)
shmem_kb=$(read_meminfo Shmem)
sreclaimable_kb=$(read_meminfo SReclaimable)

# Calculate used/buff/cache the same way free does
# buff/cache = Buffers + Cached + SReclaimable
buff_cache_kb=$((buffers_kb + cached_kb + sreclaimable_kb))
used_kb=$((mem_total_kb - mem_free_kb - buff_cache_kb))

# Scale values
scale_value() {
    local val=$1
    if [ "${human:-false}" = "true" ]; then
        if [ "$val" -ge $((1024*1024)) ]; then
            printf "%.1fG" "$(echo "scale=1; $val / 1024 / 1024" | bc -l 2>/dev/null || echo "0")"
        elif [ "$val" -ge 1024 ]; then
            printf "%.1fM" "$(echo "scale=1; $val / 1024" | bc -l 2>/dev/null || echo "0")"
        else
            printf "%dK" "$val"
        fi
    else
        local divisor=$((scale / 1024))
        [ "$divisor" -lt 1 ] && divisor=1
        printf "$format_k" "$((val / divisor))"
    fi
}

if [ "${human:-false}" = "true" ]; then
    # Build header and row with human-friendly output using numbers
    fmt_total=$(scale_value "$mem_total_kb")
    fmt_used=$(scale_value "$used_kb")
    fmt_free=$(scale_value "$mem_free_kb")
    fmt_shared=$(scale_value "$shmem_kb")
    fmt_bc=$(scale_value "$buff_cache_kb")
    fmt_avail=$(scale_value "$mem_available_kb")
    printf "%-8s %10s %10s %10s %10s %10s %10s\n" "" "total" "used" "free" "shared" "buff/cache" "available"
    printf "%-8s %10s %10s %10s %10s %10s %10s\n" "Mem:" "$fmt_total" "$fmt_used" "$fmt_free" "$fmt_shared" "$fmt_bc" "$fmt_avail"
else
    printf "%-8s %10s %10s %10s %10s %10s %10s\n" "" "total" "used" "free" "shared" "buff/cache" "available"
    printf "$format_k" "$((mem_total_kb / (scale/1024)))" > /dev/null 2>&1 || true
    printf "%-8s %10s %10s %10s %10s %10s %10s\n" \
        "Mem:" \
        "$(scale_value "$mem_total_kb")" \
        "$(scale_value "$used_kb")" \
        "$(scale_value "$mem_free_kb")" \
        "$(scale_value "$shmem_kb")" \
        "$(scale_value "$buff_cache_kb")" \
        "$(scale_value "$mem_available_kb")"
fi

# Swap line
if [ "${human:-false}" = "true" ]; then
    fmt_swap_total=$(scale_value "$swap_total_kb")
    fmt_swap_used=$(scale_value "$((swap_total_kb - swap_free_kb))")
    fmt_swap_free=$(scale_value "$swap_free_kb")
    printf "%-8s %10s %10s %10s\n" "Swap:" "$fmt_swap_total" "$fmt_swap_used" "$fmt_swap_free"
else
    printf "%-8s %10s %10s %10s\n" \
        "Swap:" \
        "$(scale_value "$swap_total_kb")" \
        "$(scale_value "$((swap_total_kb - swap_free_kb))")" \
        "$(scale_value "$swap_free_kb")"
fi
