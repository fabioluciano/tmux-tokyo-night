#!/usr/bin/env bash
# =============================================================================
# Plugin: hostname
# Description: Display current hostname
# Dependencies: None
# =============================================================================

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck source=src/plugin_bootstrap.sh
. "$ROOT_DIR/../plugin_bootstrap.sh"

# =============================================================================
# Plugin Configuration
# =============================================================================

# Note: hostname doesn't need cache initialization as it's a static plugin

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
    local hostname_format
    hostname_format=$(get_tmux_option "@powerkit_plugin_hostname_format" "$POWERKIT_PLUGIN_HOSTNAME_FORMAT")
    
    case "$hostname_format" in
        full)
            hostname -f 2>/dev/null || hostname
            ;;
        short|*)
            hostname -s 2>/dev/null || hostname | cut -d. -f1
            ;;
    esac
}

# Only run if executed directly (not sourced)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    load_plugin
fi
