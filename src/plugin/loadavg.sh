#!/usr/bin/env bash
# =============================================================================
# Plugin: loadavg
# Description: Display system load average
# Dependencies: None (uses /proc/loadavg on Linux, sysctl on macOS)
# =============================================================================

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck source=src/plugin_bootstrap.sh
. "$ROOT_DIR/../plugin_bootstrap.sh"

# =============================================================================
# Plugin Configuration
# =============================================================================

# Initialize cache (DRY - sets CACHE_KEY and CACHE_TTL automatically)
plugin_init "loadavg"

# Display format: "1" (1min), "5" (5min), "15" (15min), or "all" (1/5/15)
plugin_loadavg_format=$(get_tmux_option "@powerkit_plugin_loadavg_format" "$POWERKIT_PLUGIN_LOADAVG_FORMAT")

# =============================================================================
# Load Average Functions
# =============================================================================

# Get load average on Linux
get_loadavg_linux() {
    local load1 load5 load15
    
    if [[ -f /proc/loadavg ]]; then
        read -r load1 load5 load15 _ < /proc/loadavg
    else
        # Fallback to uptime command
        local uptime_output
        uptime_output=$(uptime 2>/dev/null)
        load1=$(echo "$uptime_output" | awk -F'load average:' '{print $2}' | awk -F', ' '{print $1}' | tr -d ' ')
        load5=$(echo "$uptime_output" | awk -F'load average:' '{print $2}' | awk -F', ' '{print $2}' | tr -d ' ')
        load15=$(echo "$uptime_output" | awk -F'load average:' '{print $2}' | awk -F', ' '{print $3}' | tr -d ' ')
    fi
    
    format_loadavg "$load1" "$load5" "$load15"
}

# Get load average on macOS
get_loadavg_macos() {
    # Single sysctl call with awk parsing (much faster)
    /usr/sbin/sysctl -n vm.loadavg 2>/dev/null | awk '
        {gsub(/[{}]/, ""); format="'$plugin_loadavg_format'"}
        {
            if (format == "5") print $2
            else if (format == "15") print $3
            else if (format == "all") print $1 " " $2 " " $3
            else print $1
        }
    ' || {
        # Fallback to uptime if sysctl failed
        command uptime 2>/dev/null | awk '
            {gsub(/.*load averages*: */, ""); gsub(/,/, "")}
            {
                format="'$plugin_loadavg_format'"
                if (format == "5") print $2
                else if (format == "15") print $3
                else if (format == "all") print $1 " " $2 " " $3
                else print $1
            }
        '
    }
}

# Format output based on user preference
format_loadavg() {
    local load1="$1"
    local load5="$2"
    local load15="$3"
    
    # Ensure we have valid values
    [[ -z "$load1" ]] && load1="0"
    [[ -z "$load5" ]] && load5="0"
    [[ -z "$load15" ]] && load15="0"
    
    case "$plugin_loadavg_format" in
        1)
            printf '%s' "$load1"
            ;;
        5)
            printf '%s' "$load5"
            ;;
        15)
            printf '%s' "$load15"
            ;;
        all)
            printf '%s %s %s' "$load1" "$load5" "$load15"
            ;;
        *)
            printf '%s' "$load1"
            ;;
    esac
}

# =============================================================================
# Plugin Interface Implementation
# =============================================================================

# This function is called by plugin_helpers.sh to get display decisions
# Output format: "show:accent:accent_icon:icon"
#
# Configuration options:
#   @powerkit_plugin_loadavg_display_condition    - Condition: le, lt, ge, gt, eq, always
#   @powerkit_plugin_loadavg_display_threshold    - Show only when condition is met
#   @powerkit_plugin_loadavg_warning_threshold    - Warning level (default: 2.0 * cores)
#   @powerkit_plugin_loadavg_critical_threshold   - Critical level (default: 4.0 * cores)
#   @powerkit_plugin_loadavg_warning_accent_color - Color for warning level
#   @powerkit_plugin_loadavg_critical_accent_color - Color for critical level
plugin_get_display_info() {
    local content="$1"
    local show="1"
    local accent=""
    local accent_icon=""
    local icon=""
    
    # Get number of CPU cores for default thresholds
    local num_cores
    num_cores=$(nproc 2>/dev/null || sysctl -n hw.ncpu 2>/dev/null || echo 4)
    
    # Extract numeric value from content (first number, could be decimal)
    local value
    value=$(echo "$content" | grep -oE '[0-9]+\.?[0-9]*' | head -1)
    # Convert to integer for comparison (multiply by 100)
    local value_int
    value_int=$(awk "BEGIN {printf \"%d\", $value * 100}" 2>/dev/null || echo 0)
    
    # Check display condition (hide based on threshold)
    # Use get_cached_option for performance in render loop
    local display_condition display_threshold
    display_condition=$(get_cached_option "@powerkit_plugin_loadavg_display_condition" "always")
    display_threshold=$(get_cached_option "@powerkit_plugin_loadavg_display_threshold" "")
    
    if [[ "$display_condition" != "always" ]] && [[ -n "$display_threshold" ]]; then
        local threshold_int
        threshold_int=$(awk "BEGIN {printf \"%d\", $display_threshold * 100}" 2>/dev/null || echo 0)
        if ! evaluate_condition "$value_int" "$display_condition" "$threshold_int"; then
            show="0"
        fi
    fi
    
    # Check warning/critical thresholds for color changes
    # Default: warning at 2x cores, critical at 4x cores
    local warning_multiplier critical_multiplier
    warning_multiplier=$(get_cached_option "@powerkit_plugin_loadavg_warning_threshold_multiplier" "$POWERKIT_PLUGIN_LOADAVG_WARNING_THRESHOLD_MULTIPLIER")
    critical_multiplier=$(get_cached_option "@powerkit_plugin_loadavg_critical_threshold_multiplier" "$POWERKIT_PLUGIN_LOADAVG_CRITICAL_THRESHOLD_MULTIPLIER")
    
    local warning_threshold critical_threshold
    warning_threshold=$(get_cached_option "@powerkit_plugin_loadavg_warning_threshold" "$((num_cores * warning_multiplier))")
    critical_threshold=$(get_cached_option "@powerkit_plugin_loadavg_critical_threshold" "$((num_cores * critical_multiplier))")
    
    local warning_int critical_int
    warning_int=$(awk "BEGIN {printf \"%d\", $warning_threshold * 100}" 2>/dev/null || echo 0)
    critical_int=$(awk "BEGIN {printf \"%d\", $critical_threshold * 100}" 2>/dev/null || echo 0)
    
    if [[ "$value_int" -ge "$critical_int" ]]; then
        accent=$(get_cached_option "@powerkit_plugin_loadavg_critical_accent_color" "$POWERKIT_PLUGIN_LOADAVG_CRITICAL_ACCENT_COLOR")
        accent_icon=$(get_cached_option "@powerkit_plugin_loadavg_critical_accent_color_icon" "$POWERKIT_PLUGIN_LOADAVG_CRITICAL_ACCENT_COLOR_ICON")
    elif [[ "$value_int" -ge "$warning_int" ]]; then
        accent=$(get_cached_option "@powerkit_plugin_loadavg_warning_accent_color" "$POWERKIT_PLUGIN_LOADAVG_WARNING_ACCENT_COLOR")
        accent_icon=$(get_cached_option "@powerkit_plugin_loadavg_warning_accent_color_icon" "$POWERKIT_PLUGIN_LOADAVG_WARNING_ACCENT_COLOR_ICON")
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
    if is_linux; then
        result=$(get_loadavg_linux)
    elif is_macos; then
        result=$(get_loadavg_macos)
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
