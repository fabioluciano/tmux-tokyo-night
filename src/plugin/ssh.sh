#!/usr/bin/env bash
# =============================================================================
# Plugin: ssh
# Description: Indicate when running in an SSH session
# Dependencies: None (uses environment variables)
# =============================================================================

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$ROOT_DIR/../plugin_bootstrap.sh"

plugin_init "ssh"

# =============================================================================
# SSH Detection Functions
# =============================================================================

is_ssh_session() {
    # Multiple detection methods for reliability
    [[ -n "${SSH_CLIENT:-}" ]] && return 0
    [[ -n "${SSH_TTY:-}" ]] && return 0
    [[ -n "${SSH_CONNECTION:-}" ]] && return 0
    
    # Check parent processes for sshd
    local pid=$$
    while [[ $pid -gt 1 ]]; do
        local pname
        pname=$(ps -p "$pid" -o comm= 2>/dev/null)
        [[ "$pname" == "sshd" || "$pname" == "ssh" ]] && return 0
        pid=$(ps -p "$pid" -o ppid= 2>/dev/null | tr -d ' ')
        [[ -z "$pid" ]] && break
    done
    
    return 1
}

get_ssh_info() {
    local format
    format=$(get_cached_option "@powerkit_plugin_ssh_format" "$POWERKIT_PLUGIN_SSH_FORMAT")
    
    case "$format" in
        host)
            # Show remote host connecting from
            echo "${SSH_CONNECTION%% *}" 2>/dev/null
            ;;
        user)
            # Show remote user
            whoami 2>/dev/null
            ;;
        full)
            # Show user@hostname
            echo "$(whoami)@$(hostname -s 2>/dev/null || hostname)"
            ;;
        indicator|*)
            # Just show indicator text
            local text
            text=$(get_cached_option "@powerkit_plugin_ssh_text" "$POWERKIT_PLUGIN_SSH_TEXT")
            echo "$text"
            ;;
    esac
}

# =============================================================================
# Plugin Interface
# =============================================================================

plugin_get_type() { printf 'conditional'; }

plugin_get_display_info() {
    local content="$1"
    if [[ -n "$content" ]]; then
        local accent accent_icon
        accent=$(get_cached_option "@powerkit_plugin_ssh_active_accent_color" "$POWERKIT_PLUGIN_SSH_ACTIVE_ACCENT_COLOR")
        accent_icon=$(get_cached_option "@powerkit_plugin_ssh_active_accent_color_icon" "$POWERKIT_PLUGIN_SSH_ACTIVE_ACCENT_COLOR_ICON")
        build_display_info "1" "$accent" "$accent_icon" ""
    else
        build_display_info "0" "" "" ""
    fi
}

# =============================================================================
# Main
# =============================================================================

load_plugin() {
    local show_local
    show_local=$(get_cached_option "@powerkit_plugin_ssh_show_when_local" "$POWERKIT_PLUGIN_SSH_SHOW_WHEN_LOCAL")
    
    # Check if we're in SSH session
    if ! is_ssh_session; then
        [[ "$show_local" == "true" ]] && echo "local" || return 0
        return 0
    fi
    
    # We're in SSH - get info based on format
    get_ssh_info
}

[[ "${BASH_SOURCE[0]}" == "${0}" ]] && load_plugin || true
