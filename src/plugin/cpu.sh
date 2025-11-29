#!/usr/bin/env bash
# =============================================================================
# Plugin: cpu
# Description: Display CPU usage percentage
# Dependencies: None (uses /proc/stat on Linux, vm_stat on macOS)
# =============================================================================

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck source=src/defaults.sh
. "$ROOT_DIR/../defaults.sh"
# shellcheck source=src/utils.sh
. "$ROOT_DIR/../utils.sh"
# shellcheck source=src/cache.sh
. "$ROOT_DIR/../cache.sh"

# =============================================================================
# Plugin Configuration
# =============================================================================

# shellcheck disable=SC2034
plugin_cpu_icon=$(get_tmux_option "@theme_plugin_cpu_icon" "$PLUGIN_CPU_ICON")
# shellcheck disable=SC2034
plugin_cpu_accent_color=$(get_tmux_option "@theme_plugin_cpu_accent_color" "$PLUGIN_CPU_ACCENT_COLOR")
# shellcheck disable=SC2034
plugin_cpu_accent_color_icon=$(get_tmux_option "@theme_plugin_cpu_accent_color_icon" "$PLUGIN_CPU_ACCENT_COLOR_ICON")

# Cache TTL in seconds (default: 2 seconds)
CACHE_TTL=$(get_tmux_option "@theme_plugin_cpu_cache_ttl" "$PLUGIN_CPU_CACHE_TTL")
CACHE_KEY="cpu"

export plugin_cpu_icon plugin_cpu_accent_color plugin_cpu_accent_color_icon

# =============================================================================
# CPU Calculation Functions
# =============================================================================

# Get CPU usage on Linux using /proc/stat
get_cpu_linux() {
    local cpu_line
    local -a cpu_values
    local idle_prev total_prev idle_curr total_curr
    local diff_idle diff_total cpu_usage

    # Read first measurement
    cpu_line=$(grep '^cpu ' /proc/stat)
    read -ra cpu_values <<< "${cpu_line#cpu }"
    
    idle_prev=${cpu_values[3]}
    total_prev=0
    for val in "${cpu_values[@]}"; do
        total_prev=$((total_prev + val))
    done

    # Wait a bit for second measurement
    sleep 0.1

    # Read second measurement
    cpu_line=$(grep '^cpu ' /proc/stat)
    read -ra cpu_values <<< "${cpu_line#cpu }"
    
    idle_curr=${cpu_values[3]}
    total_curr=0
    for val in "${cpu_values[@]}"; do
        total_curr=$((total_curr + val))
    done

    # Calculate difference
    diff_idle=$((idle_curr - idle_prev))
    diff_total=$((total_curr - total_prev))

    # Calculate CPU usage percentage
    if [[ $diff_total -gt 0 ]]; then
        cpu_usage=$(( (1000 * (diff_total - diff_idle) / diff_total + 5) / 10 ))
    else
        cpu_usage=0
    fi

    printf '%d%%' "$cpu_usage"
}

# Get CPU usage on macOS using ps (much faster than top -l 1 which takes ~1s)
get_cpu_macos() {
    local cpu_usage num_cores
    
    # Get number of CPU cores
    num_cores=$(sysctl -n hw.ncpu 2>/dev/null || echo 1)
    
    # Use ps to aggregate CPU usage across all processes
    # Then divide by number of cores to get average utilization
    cpu_usage=$(ps -A -o %cpu | awk -v cores="$num_cores" '
        NR>1 {sum+=$1} 
        END {
            avg = sum / cores
            if (avg > 100) avg = 100
            printf "%.0f", avg
        }
    ')
    
    printf '%s%%' "${cpu_usage:-0}"
}

# =============================================================================
# Main Plugin Logic
# =============================================================================

load_plugin() {
    # Check cache first
    local cached_value
    if cached_value=$(cache_get "$CACHE_KEY" "$CACHE_TTL"); then
        printf '%s' "$cached_value"
        return
    fi

    local result
    # Use cached OS detection from utils.sh
    if is_linux; then
        result=$(get_cpu_linux)
    elif is_macos; then
        result=$(get_cpu_macos)
    else
        result="N/A"
    fi

    # Update cache
    cache_set "$CACHE_KEY" "$result"
    
    printf '%s' "$result"
}

# Only run if executed directly (not sourced)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    load_plugin
fi
