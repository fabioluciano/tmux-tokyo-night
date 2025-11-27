#!/usr/bin/env bash
# =============================================================================
# Plugin: hostname
# Description: Display current hostname
# Dependencies: None
# =============================================================================

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck source=src/utils.sh
. "$ROOT_DIR/../utils.sh"

# =============================================================================
# Plugin Configuration
# =============================================================================

# shellcheck disable=SC2034
plugin_hostname_icon=$(get_tmux_option "@theme_plugin_hostname_icon" "󰒋 ")
# shellcheck disable=SC2034
plugin_hostname_accent_color=$(get_tmux_option "@theme_plugin_hostname_accent_color" "blue7")
# shellcheck disable=SC2034
plugin_hostname_accent_color_icon=$(get_tmux_option "@theme_plugin_hostname_accent_color_icon" "blue0")

export plugin_hostname_icon plugin_hostname_accent_color plugin_hostname_accent_color_icon

# =============================================================================
# Main Plugin Logic
# =============================================================================

load_plugin() {
    local hostname_format
    hostname_format=$(get_tmux_option "@theme_plugin_hostname_format" "short")
    
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
