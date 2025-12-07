#!/usr/bin/env bash
# =============================================================================
# Plugin: external_ip
# Description: Display the external (public) IP address
# Dependencies: curl
# =============================================================================

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck source=src/plugin_bootstrap.sh
. "$ROOT_DIR/../plugin_bootstrap.sh"

# =============================================================================
# Plugin Configuration
# =============================================================================

# Initialize cache (DRY - sets CACHE_KEY and CACHE_TTL automatically)
plugin_init "external_ip"

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

# Function to inform the plugin type to the renderer
plugin_get_type() {
    printf 'conditional'
}

# NOTE: plugin_get_display_info() removed - uses centralized theme-controlled system
# No custom threshold/icon logic needed for this plugin

# =============================================================================
# Main Plugin Logic
# =============================================================================

load_plugin() {
    # Check cache first
    local cached_value
    if cached_value=$(cache_get "$CACHE_KEY" "$CACHE_TTL"); then
        printf '%s' "$cached_value"
        return 0
    fi
    
    local ip
    ip=$(get_external_ip)
    
    if [[ -z "$ip" ]]; then
        return 0
    fi
    
    cache_set "$CACHE_KEY" "$ip"
    printf '%s' "$ip"
}

# Only run if executed directly (not sourced)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    load_plugin
fi
