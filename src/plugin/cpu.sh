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
# shellcheck source=src/plugin_interface.sh
. "$ROOT_DIR/../plugin_interface.sh"

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
# Plugin Interface Implementation
# =============================================================================

# This function is called by render_plugins.sh to get display decisions
# Output format: "show:accent:accent_icon:icon"
#
# Configuration options:
#   @theme_plugin_cpu_display_condition    - Condition: le, lt, ge, gt, eq, always
#   @theme_plugin_cpu_display_threshold    - Show only when condition is met
#   @theme_plugin_cpu_warning_threshold    - Warning level (default: 70)
#   @theme_plugin_cpu_critical_threshold   - Critical level (default: 90)
#   @theme_plugin_cpu_warning_accent_color - Color for warning level
#   @theme_plugin_cpu_critical_accent_color - Color for critical level
plugin_get_display_info() {
    local content="$1"
    local show="1"
    local accent=""
    local accent_icon=""
    local icon=""
    
    # Extract numeric value from content
    local value
    value=$(extract_numeric "$content")
    
    # Check display condition (hide based on threshold)
    # Use get_cached_option for performance in render loop
    local display_condition display_threshold
    display_condition=$(get_cached_option "@theme_plugin_cpu_display_condition" "always")
    display_threshold=$(get_cached_option "@theme_plugin_cpu_display_threshold" "")
    
    if [[ "$display_condition" != "always" ]] && [[ -n "$display_threshold" ]]; then
        if ! evaluate_condition "$value" "$display_condition" "$display_threshold"; then
            show="0"
        fi
    fi
    
    # Check warning/critical thresholds for color changes
    local warning_threshold critical_threshold
    warning_threshold=$(get_cached_option "@theme_plugin_cpu_warning_threshold" "$PLUGIN_CPU_WARNING_THRESHOLD")
    critical_threshold=$(get_cached_option "@theme_plugin_cpu_critical_threshold" "$PLUGIN_CPU_CRITICAL_THRESHOLD")
    
    if [[ -n "$value" ]]; then
        if [[ "$value" -ge "$critical_threshold" ]]; then
            accent=$(get_cached_option "@theme_plugin_cpu_critical_accent_color" "$PLUGIN_CPU_CRITICAL_ACCENT_COLOR")
            accent_icon=$(get_cached_option "@theme_plugin_cpu_critical_accent_color_icon" "$PLUGIN_CPU_CRITICAL_ACCENT_COLOR_ICON")
        elif [[ "$value" -ge "$warning_threshold" ]]; then
            accent=$(get_cached_option "@theme_plugin_cpu_warning_accent_color" "$PLUGIN_CPU_WARNING_ACCENT_COLOR")
            accent_icon=$(get_cached_option "@theme_plugin_cpu_warning_accent_color_icon" "$PLUGIN_CPU_WARNING_ACCENT_COLOR_ICON")
        fi
    fi
    
    build_display_info "$show" "$accent" "$accent_icon" "$icon"
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
