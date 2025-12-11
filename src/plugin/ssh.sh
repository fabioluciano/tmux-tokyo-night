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

is_ssh_in_current_pane() {
    # Check if the current focused pane is running SSH
    local pane_pid
    pane_pid=$(tmux display-message -p "#{pane_pid}" 2>/dev/null)
    [[ -z "$pane_pid" ]] && return 1

    # Get all children of the pane process
    local all_pids
    all_pids=$(pgrep -P "$pane_pid" 2>/dev/null)

    # Check the pane process and its children
    for pid in $pane_pid $all_pids; do
        local cmd
        cmd=$(ps -p "$pid" -o comm= 2>/dev/null)

        # Match ssh, sshd, or any SSH-related process
        if [[ "$cmd" == "ssh" || "$cmd" == "sshd" || "$cmd" == *"ssh"* ]]; then
            # Get more details about the SSH connection
            local full_cmd
            full_cmd=$(ps -p "$pid" -o args= 2>/dev/null)

            # Filter out ssh-agent and other non-connection SSH processes
            if [[ "$full_cmd" != *"ssh-agent"* && "$full_cmd" != *"ssh-keygen"* ]]; then
                return 0
            fi
        fi
    done

    return 1
}

is_ssh_in_any_pane() {
    # Check if any tmux pane is running SSH
    local pane_pids
    pane_pids=$(tmux list-panes -a -F "#{pane_pid}" 2>/dev/null)
    [[ -z "$pane_pids" ]] && return 1

    while IFS= read -r pane_pid; do
        [[ -z "$pane_pid" ]] && continue

        # Get all children of the pane process
        local all_pids
        all_pids=$(pgrep -P "$pane_pid" 2>/dev/null)

        # Check the pane process and its children
        for pid in $pane_pid $all_pids; do
            local cmd
            cmd=$(ps -p "$pid" -o comm= 2>/dev/null)

            # Match ssh, sshd, or any SSH-related process
            if [[ "$cmd" == "ssh" || "$cmd" == "sshd" || "$cmd" == *"ssh"* ]]; then
                # Get more details about the SSH connection
                local full_cmd
                full_cmd=$(ps -p "$pid" -o args= 2>/dev/null)

                # Filter out ssh-agent and other non-connection SSH processes
                if [[ "$full_cmd" != *"ssh-agent"* && "$full_cmd" != *"ssh-keygen"* ]]; then
                    return 0
                fi
            fi
        done
    done <<< "$pane_pids"

    return 1
}

get_ssh_target_from_pane() {
    # Extract SSH target from the current pane's SSH process
    local pane_pid
    pane_pid=$(tmux display-message -p "#{pane_pid}" 2>/dev/null)
    [[ -z "$pane_pid" ]] && return 1

    # Get all children of the pane process
    local all_pids
    all_pids=$(pgrep -P "$pane_pid" 2>/dev/null)

    # Find the SSH process and extract connection info
    for pid in $all_pids $pane_pid; do
        local cmd
        cmd=$(ps -p "$pid" -o comm= 2>/dev/null)

        if [[ "$cmd" == "ssh" ]]; then
            local full_cmd
            full_cmd=$(ps -p "$pid" -o args= 2>/dev/null)

            # Extract target from SSH command line
            # Matches patterns like: ssh user@host, ssh host, ssh -p 2222 user@host
            if [[ "$full_cmd" =~ ([^[:space:]@-]+@[^[:space:]]+)$ ]]; then
                # Found user@host pattern
                echo "${BASH_REMATCH[1]}"
                return 0
            elif [[ "$full_cmd" =~ ssh[[:space:]]+([^[:space:]]+)$ ]]; then
                # Found just hostname
                echo "${BASH_REMATCH[1]}"
                return 0
            fi
        fi
    done

    return 1
}

get_ssh_info() {
    local format
    format=$(get_cached_option "@powerkit_plugin_ssh_format" "$POWERKIT_PLUGIN_SSH_FORMAT")

    case "$format" in
        host)
            # Show remote host connecting from (for session-level SSH)
            if [[ -n "${SSH_CONNECTION:-}" ]]; then
                echo "${SSH_CONNECTION%% *}" 2>/dev/null
            else
                # For pane-level SSH, extract hostname
                local target
                target=$(get_ssh_target_from_pane)
                if [[ "$target" == *@* ]]; then
                    echo "${target#*@}"
                else
                    echo "$target"
                fi
            fi
            ;;
        user)
            # Show remote user
            if [[ -n "${SSH_CONNECTION:-}" ]]; then
                whoami 2>/dev/null
            else
                local target
                target=$(get_ssh_target_from_pane)
                if [[ "$target" == *@* ]]; then
                    echo "${target%@*}"
                else
                    whoami 2>/dev/null
                fi
            fi
            ;;
        full|auto|*)
            # Show user@hostname or just hostname
            if [[ -n "${SSH_CONNECTION:-}" ]]; then
                echo "$(whoami)@$(hostname -s 2>/dev/null || hostname)"
            else
                local target
                target=$(get_ssh_target_from_pane)
                if [[ -n "$target" ]]; then
                    echo "$target"
                else
                    local text
                    text=$(get_cached_option "@powerkit_plugin_ssh_text" "$POWERKIT_PLUGIN_SSH_TEXT")
                    echo "$text"
                fi
            fi
            ;;
        indicator)
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
    local show_local detection_mode
    show_local=$(get_cached_option "@powerkit_plugin_ssh_show_when_local" "$POWERKIT_PLUGIN_SSH_SHOW_WHEN_LOCAL")
    detection_mode=$(get_cached_option "@powerkit_plugin_ssh_detection_mode" "$POWERKIT_PLUGIN_SSH_DETECTION_MODE")

    local in_ssh=false

    # Determine if we're in SSH based on detection mode
    case "$detection_mode" in
        session)
            is_ssh_session && in_ssh=true
            ;;
        current)
            # Check only the current focused pane
            is_ssh_in_current_pane && in_ssh=true
            ;;
        any|*)
            # Check both session-level and any pane
            if is_ssh_session || is_ssh_in_any_pane; then
                in_ssh=true
            fi
            ;;
    esac

    # Check if we're in SSH
    if [[ "$in_ssh" != "true" ]]; then
        [[ "$show_local" == "true" ]] && echo "local" || return 0
        return 0
    fi

    # We're in SSH - get info based on format
    get_ssh_info
}

[[ "${BASH_SOURCE[0]}" == "${0}" ]] && load_plugin || true
