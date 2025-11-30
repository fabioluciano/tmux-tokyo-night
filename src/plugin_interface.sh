#!/usr/bin/env bash
# =============================================================================
# Plugin Interface
# Standard interface for plugins to define their behavior.
#
# Each plugin can implement these functions to customize behavior:
#
# REQUIRED (one of):
#   load_plugin()          - Returns the plugin content (called when executed directly)
#
# OPTIONAL (for dynamic behavior):
#   plugin_get_display_info() - Returns display decision and colors
#                               Output format: "show:accent:accent_icon:icon"
#                               - show: "1" to display, "0" to hide
#                               - accent: accent color (or empty to use default)
#                               - accent_icon: icon accent color (or empty to use default)
#                               - icon: icon override (or empty to use default)
#
# The render system will:
# 1. Execute the plugin script to get content
# 2. If plugin defines plugin_get_display_info, call it with the content
# 3. Use the returned values to decide display and colors
#
# Example implementation in a plugin:
#
#   plugin_get_display_info() {
#       local content="$1"
#       local value
#       value=$(echo "$content" | grep -oE '[0-9]+' | head -1)
#       
#       # Example: hide if value > 50, change color if value > 80
#       local show="1" accent="" accent_icon="" icon=""
#       
#       if [[ -n "$value" ]] && [[ "$value" -gt 50 ]]; then
#           show="0"
#       elif [[ -n "$value" ]] && [[ "$value" -gt 80 ]]; then
#           accent="red"
#           accent_icon="red1"
#           icon="󰀦"
#       fi
#       
#       printf '%s:%s:%s:%s' "$show" "$accent" "$accent_icon" "$icon"
#   }
#
# =============================================================================

# Source guard
# shellcheck disable=SC2317
if [[ -n "${_PLUGIN_INTERFACE_LOADED:-}" ]]; then
    return 0 2>/dev/null || true
fi
_PLUGIN_INTERFACE_LOADED=1

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck source=src/utils.sh
. "$ROOT_DIR/utils.sh"

# =============================================================================
# Helper Functions for Plugins
# These functions are called indirectly by plugins that source this file
# =============================================================================

# shellcheck disable=SC2317
# Evaluate a display condition
# Usage: evaluate_condition <value> <condition> <threshold>
# Returns: 0 if condition is met, 1 otherwise
evaluate_condition() {
    local value="$1"
    local condition="$2"
    local threshold="$3"
    
    [[ "$condition" == "always" ]] && return 0
    [[ -z "$threshold" ]] && return 0
    [[ -z "$value" ]] && return 0
    
    case "$condition" in
        lt) [[ "$value" -lt "$threshold" ]] && return 0 ;;
        le) [[ "$value" -le "$threshold" ]] && return 0 ;;
        gt) [[ "$value" -gt "$threshold" ]] && return 0 ;;
        ge) [[ "$value" -ge "$threshold" ]] && return 0 ;;
        eq) [[ "$value" -eq "$threshold" ]] && return 0 ;;
        ne) [[ "$value" -ne "$threshold" ]] && return 0 ;;
    esac
    
    return 1
}

# Extract numeric value from content
# Usage: extract_numeric <content>
extract_numeric() {
    local content="$1"
    echo "$content" | grep -oE '[0-9]+' | head -1
}

# Build display info string
# Usage: build_display_info <show> [accent] [accent_icon] [icon]
build_display_info() {
    local show="${1:-1}"
    local accent="${2:-}"
    local accent_icon="${3:-}"
    local icon="${4:-}"
    
    printf '%s:%s:%s:%s' "$show" "$accent" "$accent_icon" "$icon"
}
