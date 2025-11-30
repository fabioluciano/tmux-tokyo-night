#!/usr/bin/env bash
# =============================================================================
# Plugin: external_ip
# Description: Display the external (public) IP address
# Dependencies: curl
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
plugin_external_ip_icon=$(get_tmux_option "@theme_plugin_external_ip_icon" "$PLUGIN_EXTERNAL_IP_ICON")
# shellcheck disable=SC2034
plugin_external_ip_accent_color=$(get_tmux_option "@theme_plugin_external_ip_accent_color" "$PLUGIN_EXTERNAL_IP_ACCENT_COLOR")
# shellcheck disable=SC2034
plugin_external_ip_accent_color_icon=$(get_tmux_option "@theme_plugin_external_ip_accent_color_icon" "$PLUGIN_EXTERNAL_IP_ACCENT_COLOR_ICON")

# Cache settings
EXTERNAL_IP_CACHE_TTL=$(get_tmux_option "@theme_plugin_external_ip_cache_ttl" "$PLUGIN_EXTERNAL_IP_CACHE_TTL")
EXTERNAL_IP_CACHE_KEY="external_ip"

# =============================================================================
# External IP Detection
# =============================================================================

get_external_ip() {
    command -v curl &>/dev/null || return 1
    local ip
    ip=$(curl -s --connect-timeout 3 --max-time 5 https://api.ipify.org 2>/dev/null)
    [[ -n "$ip" ]] && printf '%s' "$ip" && return 0
    return 1
}

# =============================================================================
# Plugin Interface Implementation
# =============================================================================

plugin_get_display_info() {
    local content="$1"
    local show="1"
    local accent=""
    local accent_icon=""
    local icon=""
    
    build_display_info "$show" "$accent" "$accent_icon" "$icon"
}

# =============================================================================
# Main Plugin Logic
# =============================================================================

load_plugin() {
    # Check cache first
    local cached_value
    if cached_value=$(cache_get "$EXTERNAL_IP_CACHE_KEY" "$EXTERNAL_IP_CACHE_TTL"); then
        printf '%s' "$cached_value"
        return 0
    fi
    
    local ip
    ip=$(get_external_ip)
    
    if [[ -z "$ip" ]]; then
        return 0
    fi
    
    cache_set "$EXTERNAL_IP_CACHE_KEY" "$ip"
    printf '%s' "$ip"
}

# Only run if executed directly (not sourced)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    load_plugin
fi
