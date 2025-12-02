#!/usr/bin/env bash
# =============================================================================
# Plugin: memory
# Description: Display memory usage percentage
# Dependencies: None (uses /proc/meminfo on Linux, vm_stat on macOS)
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
plugin_memory_icon=$(get_tmux_option "@theme_plugin_memory_icon" "$PLUGIN_MEMORY_ICON")
# shellcheck disable=SC2034
plugin_memory_accent_color=$(get_tmux_option "@theme_plugin_memory_accent_color" "$PLUGIN_MEMORY_ACCENT_COLOR")
# shellcheck disable=SC2034
plugin_memory_accent_color_icon=$(get_tmux_option "@theme_plugin_memory_accent_color_icon" "$PLUGIN_MEMORY_ACCENT_COLOR_ICON")

# Cache TTL in seconds (default: 5 seconds)
CACHE_TTL=$(get_tmux_option "@theme_plugin_memory_cache_ttl" "$PLUGIN_MEMORY_CACHE_TTL")
CACHE_KEY="memory"

# Display format: "percent" or "usage" (e.g., "4.2G/16G")
plugin_memory_format=$(get_tmux_option "@theme_plugin_memory_format" "$PLUGIN_MEMORY_FORMAT")

export plugin_memory_icon plugin_memory_accent_color plugin_memory_accent_color_icon

# =============================================================================
# Memory Calculation Functions
# =============================================================================

# Convert bytes to human readable format
bytes_to_human() {
    local bytes=$1
    local gb
    
    # 1 GiB in bytes (1024^3) 
    gb=$((bytes / 1073741824))
    
    if [[ $gb -gt 0 ]]; then
        # Use awk for floating point (faster than bc and more portable)
        awk -v b="$bytes" 'BEGIN {printf "%.1fG", b / 1073741824}'
    else
        # Show in MB if less than 1 GB
        local mb=$((bytes / 1048576)) # 1 MiB in bytes (1024^2)
        printf '%dM' "$mb"
    fi
}

# Get memory usage on Linux
get_memory_linux() {
    local mem_total mem_available mem_used percent
    
    mem_total=$(command grep '^MemTotal:' /proc/meminfo | command awk '{print $2}')
    mem_available=$(command grep '^MemAvailable:' /proc/meminfo | command awk '{print $2}')
    
    # MemAvailable might not exist on older kernels
    if [[ -z "$mem_available" ]]; then
        local mem_free mem_buffers mem_cached
        mem_free=$(command grep '^MemFree:' /proc/meminfo | command awk '{print $2}')
        mem_buffers=$(command grep '^Buffers:' /proc/meminfo | command awk '{print $2}')
        mem_cached=$(command grep '^Cached:' /proc/meminfo | command awk '{print $2}')
        mem_available=$((mem_free + mem_buffers + mem_cached))
    fi
    
    mem_used=$((mem_total - mem_available))
    percent=$(( (mem_used * 100) / mem_total ))
    
    if [[ "$plugin_memory_format" == "usage" ]]; then
        local used_bytes=$((mem_used * 1024))
        local total_bytes=$((mem_total * 1024))
        printf '%s/%s' "$(bytes_to_human $used_bytes)" "$(bytes_to_human $total_bytes)"
    else
        printf '%d%%' "$percent"
    fi
}

# Get memory usage on macOS
get_memory_macos() {
    local page_size mem_total mem_used percent
    
    page_size=$(pagesize 2>/dev/null || sysctl -n hw.pagesize)
    mem_total=$(sysctl -n hw.memsize)
    
    # Get memory pages from vm_stat
    local vm_stat_output
    vm_stat_output=$(vm_stat)
    
    local pages_active pages_wired
    pages_active=$(echo "$vm_stat_output" | grep "Pages active:" | awk '{print $3}' | tr -d '.')
    pages_wired=$(echo "$vm_stat_output" | grep "Pages wired down:" | awk '{print $4}' | tr -d '.')
    
    # Calculate used memory (active + wired)
    local pages_used=$((pages_active + pages_wired))
    mem_used=$((pages_used * page_size))
    
    percent=$(( (mem_used * 100) / mem_total ))
    
    if [[ "$plugin_memory_format" == "usage" ]]; then
        printf '%s/%s' "$(bytes_to_human "$mem_used")" "$(bytes_to_human "$mem_total")"
    else
        printf '%d%%' "$percent"
    fi
}

# =============================================================================
# Plugin Interface Implementation
# =============================================================================

# This function is called by render_plugins.sh to get display decisions
# Output format: "show:accent:accent_icon:icon"
#
# Configuration options:
#   @theme_plugin_memory_display_condition    - Condition: le, lt, ge, gt, eq, always
#   @theme_plugin_memory_display_threshold    - Show only when condition is met
#   @theme_plugin_memory_warning_threshold    - Warning level (default: 70)
#   @theme_plugin_memory_critical_threshold   - Critical level (default: 90)
#   @theme_plugin_memory_warning_accent_color - Color for warning level
#   @theme_plugin_memory_critical_accent_color - Color for critical level
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
    display_condition=$(get_cached_option "@theme_plugin_memory_display_condition" "always")
    display_threshold=$(get_cached_option "@theme_plugin_memory_display_threshold" "")
    
    if [[ "$display_condition" != "always" ]] && [[ -n "$display_threshold" ]]; then
        if ! evaluate_condition "$value" "$display_condition" "$display_threshold"; then
            show="0"
        fi
    fi
    
    # Check warning/critical thresholds for color changes
    local warning_threshold critical_threshold
    warning_threshold=$(get_cached_option "@theme_plugin_memory_warning_threshold" "$PLUGIN_MEMORY_WARNING_THRESHOLD")
    critical_threshold=$(get_cached_option "@theme_plugin_memory_critical_threshold" "$PLUGIN_MEMORY_CRITICAL_THRESHOLD")
    
    if [[ -n "$value" ]]; then
        if [[ "$value" -ge "$critical_threshold" ]]; then
            accent=$(get_cached_option "@theme_plugin_memory_critical_accent_color" "$PLUGIN_MEMORY_CRITICAL_ACCENT_COLOR")
            accent_icon=$(get_cached_option "@theme_plugin_memory_critical_accent_color_icon" "$PLUGIN_MEMORY_CRITICAL_ACCENT_COLOR_ICON")
        elif [[ "$value" -ge "$warning_threshold" ]]; then
            accent=$(get_cached_option "@theme_plugin_memory_warning_accent_color" "$PLUGIN_MEMORY_WARNING_ACCENT_COLOR")
            accent_icon=$(get_cached_option "@theme_plugin_memory_warning_accent_color_icon" "$PLUGIN_MEMORY_WARNING_ACCENT_COLOR_ICON")
        fi
    fi
    
    build_display_info "$show" "$accent" "$accent_icon" "$icon"
}

# =============================================================================
# Plugin Interface Implementation
# =============================================================================

# Function to inform the plugin type to the renderer
plugin_get_type() {
    printf 'static'
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
        result=$(get_memory_linux)
    elif is_macos; then
        result=$(get_memory_macos)
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
