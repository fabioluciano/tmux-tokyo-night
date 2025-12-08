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

# Check for active GPG operations (not gpg-agent)
check_gpg_active() {
    pgrep -f "gpg[2]?\s" 2>/dev/null | while read -r pid; do
        ps -p "$pid" -o comm= 2>/dev/null | grep -qv "gpg-agent" && return 0
    done
    return 1
}

# Check scdaemon CPU activity (smart card daemon)
check_scdaemon_active() {
    local pid cpu
    pid=$(pgrep -f "scdaemon" | head -1) || return 1
    cpu=$(ps -p "$pid" -o %cpu= 2>/dev/null | tr -d ' ' | cut -d. -f1)
    [[ -n "$cpu" && "$cpu" -gt 0 ]] 2>/dev/null
}

# Check pcscd CPU activity (PC/SC daemon)
check_pcscd_active() {
    local pid cpu
    pid=$(pgrep -f "pcscd" | head -1) || return 1
    cpu=$(ps -p "$pid" -o %cpu= 2>/dev/null | tr -d ' ' | cut -d. -f1)
    [[ -n "$cpu" && "$cpu" -gt 3 ]] 2>/dev/null
}

# =============================================================================
# Main Detection
# =============================================================================

is_waiting_for_touch() {
    # Priority: pinentry > gpg active > scdaemon > pcscd
    check_pinentry && return 0
    check_gpg_active && return 0
    check_scdaemon_active && return 0
    check_pcscd_active && return 0
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
