#!/usr/bin/env bash
# =============================================================================
# Plugin Helper Functions
# Lightweight utilities for plugins - no rendering functionality
# =============================================================================

# Source guard
if [[ -n "${_PLUGIN_HELPERS_LOADED:-}" ]]; then
    return 0 2>/dev/null || true
fi
_PLUGIN_HELPERS_LOADED=1

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck source=src/utils.sh
. "$ROOT_DIR/utils.sh"

# =============================================================================
# Plugin Initialization Helpers (DRY)
# =============================================================================

# Get plugin-specific option from tmux
# Usage: get_plugin_option <option_name> <default_value>
# Requires: CACHE_KEY to be set (from plugin_init)
# Example: get_plugin_option "icon" "󰌵" -> gets @powerkit_plugin_camera_icon
get_plugin_option() {
    local option_name="$1"
    local default_value="$2"
    local plugin_name="${CACHE_KEY:-unknown}"
    
    get_tmux_option "@powerkit_plugin_${plugin_name}_${option_name}" "$default_value"
}

# Initialize plugin cache settings
# Usage: plugin_init <plugin_name>
# Sets: CACHE_KEY, CACHE_TTL
# Example: plugin_init "cpu" -> CACHE_KEY="cpu", CACHE_TTL from config
plugin_init() {
    local plugin_name="$1"
    local plugin_upper="${plugin_name^^}"
    plugin_upper="${plugin_upper//-/_}"  # replace - with _
    
    # Set cache key
    CACHE_KEY="$plugin_name"
    
    # Get cache TTL from config or defaults
    local ttl_var="POWERKIT_PLUGIN_${plugin_upper}_CACHE_TTL"
    local default_ttl="${!ttl_var:-5}"
    CACHE_TTL=$(get_tmux_option "@powerkit_plugin_${plugin_name}_cache_ttl" "$default_ttl")
    
    export CACHE_KEY CACHE_TTL
}

# =============================================================================
# Helper Functions for Plugins
# =============================================================================

# Helper function for getting tmux options in plugins
get_cached_option() {
    get_tmux_option "$@"
}

# Evaluate a display condition
# Usage: evaluate_condition <value> <condition> <threshold>
# Returns: 0 if condition is met, 1 otherwise
evaluate_condition() {
    local value="$1"
    local condition="$2"
    local threshold="$3"
    
    [[ "$condition" == "$POWERKIT_CONDITION_ALWAYS" ]] && return 0
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