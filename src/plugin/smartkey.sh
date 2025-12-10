#!/usr/bin/env bash
# =============================================================================
# Plugin: smartkey
# Description: Display hardware key/smart card touch status
# Dependencies: None (detects YubiKey, SoloKeys, Nitrokey via gpg/piv)
# =============================================================================

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$ROOT_DIR/../plugin_bootstrap.sh"

plugin_init "smartkey"

# =============================================================================
# Detection Functions
# =============================================================================

# Check for pinentry (PIN/touch prompt)
check_pinentry() {
    pgrep -f "pinentry" &>/dev/null
}

# Check for active GPG operations (waiting for user)
# Uses gpg-connect-agent with short timeout - if it hangs, something is waiting
check_gpg_waiting() {
    command -v gpg-connect-agent &>/dev/null || return 1
    # If agent is blocked waiting for touch, SCD commands will hang
    # Use 0.5s timeout - if it times out, agent is busy waiting
    ! timeout 0.5 gpg-connect-agent "SCD GETINFO version" /bye &>/dev/null 2>&1
}

# Check for ssh-agent operations waiting (ssh-sk provider)
check_ssh_waiting() {
    # Check for ssh processes in uninterruptible sleep (waiting for key)
    local ssh_pids
    ssh_pids=$(pgrep -f "^ssh " 2>/dev/null) || return 1
    for pid in $ssh_pids; do
        local state
        state=$(ps -p "$pid" -o state= 2>/dev/null)
        # U = uninterruptible wait (often IO/device wait)
        [[ "$state" == *"U"* ]] && return 0
    done
    return 1
}

# Check scdaemon state (smart card daemon)
check_scdaemon_busy() {
    local pid
    pid=$(pgrep -f "scdaemon" | head -1) || return 1
    # Check if scdaemon has open connections (indicates active operation)
    local conns
    conns=$(lsof -p "$pid" 2>/dev/null | grep -c "unix" || echo 0)
    [[ "$conns" -gt 2 ]] 2>/dev/null
}

# =============================================================================
# Main Detection
# =============================================================================

is_waiting_for_touch() {
    # Priority: pinentry > gpg waiting > ssh waiting > scdaemon busy
    check_pinentry && return 0
    check_gpg_waiting && return 0
    check_ssh_waiting && return 0
    check_scdaemon_busy && return 0
    return 1
}

# =============================================================================
# Plugin Interface
# =============================================================================

plugin_get_type() { printf 'conditional'; }

plugin_get_display_info() {
    local content="$1"
    if [[ -n "$content" ]]; then
        # Waiting state - use warning colors
        echo "1:$POWERKIT_PLUGIN_SMARTKEY_WAITING_ACCENT_COLOR:$POWERKIT_PLUGIN_SMARTKEY_WAITING_ACCENT_COLOR_ICON:$POWERKIT_PLUGIN_SMARTKEY_WAITING_ICON"
    else
        echo "0:::"
    fi
}

# =============================================================================
# Main
# =============================================================================

load_plugin() {
    local cached
    cached=$(cache_get "$CACHE_KEY" "$CACHE_TTL") && { printf '%s' "$cached"; return 0; }
    
    local result=""
    is_waiting_for_touch && result="TOUCH"
    
    cache_set "$CACHE_KEY" "$result"
    printf '%s' "$result"
}

# Only run if executed directly (not sourced)
[[ "${BASH_SOURCE[0]}" == "${0}" ]] && load_plugin || true
