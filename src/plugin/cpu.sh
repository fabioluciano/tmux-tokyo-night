#!/usr/bin/env bash
# =============================================================================
# Plugin: cpu
# Description: Display CPU usage percentage
# Dependencies: None (uses /proc/stat on Linux, vm_stat on macOS)
# =============================================================================

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck source=src/utils.sh
. "$ROOT_DIR/../utils.sh"
# shellcheck source=src/cache.sh
. "$ROOT_DIR/../cache.sh"

# =============================================================================
# Plugin Configuration
# =============================================================================

# shellcheck disable=SC2034
plugin_cpu_icon=$(get_tmux_option "@theme_plugin_cpu_icon" " ")
# shellcheck disable=SC2034
plugin_cpu_accent_color=$(get_tmux_option "@theme_plugin_cpu_accent_color" "blue7")
# shellcheck disable=SC2034
plugin_cpu_accent_color_icon=$(get_tmux_option "@theme_plugin_cpu_accent_color_icon" "blue0")

# Cache TTL in seconds (CPU updates every 2 seconds)
CACHE_TTL=2
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

# Get CPU usage on macOS using top
get_cpu_macos() {
    local cpu_usage
    
    # Use top in logging mode to get CPU usage
    cpu_usage=$(top -l 1 -n 0 2>/dev/null | grep "CPU usage" | awk '{print $3}' | tr -d '%')
    
    if [[ -z "$cpu_usage" ]]; then
        # Fallback: use ps to estimate
        cpu_usage=$(ps -A -o %cpu | awk '{sum+=$1} END {printf "%.0f", sum}')
    fi
    
    printf '%.0f%%' "$cpu_usage"
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
    case "$(uname -s)" in
        Linux*)
            result=$(get_cpu_linux)
            ;;
        Darwin*)
            result=$(get_cpu_macos)
            ;;
        *)
            result="N/A"
            ;;
    esac

    # Update cache
    cache_set "$CACHE_KEY" "$result"
    
    printf '%s' "$result"
}

load_plugin
