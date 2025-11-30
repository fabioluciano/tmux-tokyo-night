#!/usr/bin/env bash
# =============================================================================
# Plugin: vpn
# Description: Display VPN connection status
# Dependencies: None (supports WireGuard, OpenVPN, Tailscale, and system VPNs)
# =============================================================================
#
# Configuration options:
#   @theme_plugin_vpn_icon                 - Icon when connected (default: 󰌾)
#   @theme_plugin_vpn_icon_disconnected    - Icon when disconnected (default: 󰦞)
#   @theme_plugin_vpn_accent_color         - Default accent color
#   @theme_plugin_vpn_accent_color_icon    - Default icon accent color
#   @theme_plugin_vpn_show_name            - Show VPN/server name (default: true)
#   @theme_plugin_vpn_show_when_disconnected - Show when not connected (default: false)
#   @theme_plugin_vpn_max_length           - Max name length (default: 20)
#   @theme_plugin_vpn_cache_ttl            - Cache time in seconds (default: 10)
#
# Supported VPN types:
#   - Cloudflare WARP
#   - FortiClient VPN
#   - WireGuard (wg)
#   - Tailscale
#   - OpenVPN
#   - macOS System VPN (IKEv2, L2TP, etc.)
#   - NetworkManager VPN connections
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
plugin_vpn_icon=$(get_tmux_option "@theme_plugin_vpn_icon" "$PLUGIN_VPN_ICON")
# shellcheck disable=SC2034
plugin_vpn_accent_color=$(get_tmux_option "@theme_plugin_vpn_accent_color" "$PLUGIN_VPN_ACCENT_COLOR")
# shellcheck disable=SC2034
plugin_vpn_accent_color_icon=$(get_tmux_option "@theme_plugin_vpn_accent_color_icon" "$PLUGIN_VPN_ACCENT_COLOR_ICON")

# Cache settings
VPN_CACHE_TTL=$(get_tmux_option "@theme_plugin_vpn_cache_ttl" "$PLUGIN_VPN_CACHE_TTL")
VPN_CACHE_KEY="vpn"

# =============================================================================
# VPN Detection Functions
# =============================================================================

# Check Cloudflare WARP connection
check_cloudflare_warp() {
    command -v warp-cli &>/dev/null || return 1
    
    local status
    status=$(warp-cli status 2>/dev/null)
    
    if echo "$status" | grep -q "Connected"; then
        printf 'connected:Cloudflare WARP'
        return 0
    fi
    
    return 1
}

# Check FortiClient VPN connection
check_forticlient() {
    # Method 1: Check for FortiClient CLI (openfortivpn)
    if command -v openfortivpn &>/dev/null; then
        if pgrep -x "openfortivpn" &>/dev/null; then
            printf 'connected:FortiVPN'
            return 0
        fi
    fi
    
    # Method 2: Check for FortiClient process on macOS
    if is_macos; then
        # FortiClient GUI app
        if pgrep -f "FortiClient" &>/dev/null; then
            # Check if tunnel interface exists (ppp or utun created by FortiClient)
            local forti_status
            forti_status=$(scutil --nc list 2>/dev/null | grep -i "forti" | grep -E "^\*.*Connected")
            if [[ -n "$forti_status" ]]; then
                local vpn_name
                vpn_name=$(echo "$forti_status" | sed 's/.*"\([^"]*\)".*/\1/')
                printf 'connected:%s' "$vpn_name"
                return 0
            fi
            
            # Alternative: check if FortiTray shows connected
            if pgrep -f "FortiTray" &>/dev/null && ifconfig 2>/dev/null | grep -q "ppp0"; then
                printf 'connected:FortiClient'
                return 0
            fi
        fi
    fi
    
    # Method 3: Check for FortiClient on Linux
    if is_linux; then
        if pgrep -f "forticlient" &>/dev/null || pgrep -f "fortisslvpn" &>/dev/null; then
            # Check for ppp interface created by FortiClient
            if ip link show ppp0 &>/dev/null 2>&1; then
                printf 'connected:FortiClient'
                return 0
            fi
        fi
    fi
    
    return 1
}

# Check WireGuard connection
check_wireguard() {
    command -v wg &>/dev/null || return 1
    
    local interface
    interface=$(wg show interfaces 2>/dev/null | head -1)
    
    if [[ -n "$interface" ]]; then
        printf 'connected:WireGuard (%s)' "$interface"
        return 0
    fi
    
    return 1
}

# Check Tailscale connection
check_tailscale() {
    command -v tailscale &>/dev/null || return 1
    
    local status
    status=$(tailscale status --json 2>/dev/null)
    
    if [[ -z "$status" ]]; then
        return 1
    fi
    
    # Check if connected (BackendState should be "Running")
    local backend_state
    backend_state=$(echo "$status" | grep -o '"BackendState":"[^"]*"' | cut -d'"' -f4)
    
    if [[ "$backend_state" == "Running" ]]; then
        # Get current exit node or hostname
        local self_name
        self_name=$(echo "$status" | grep -o '"Self":{[^}]*"HostName":"[^"]*"' | grep -o '"HostName":"[^"]*"' | cut -d'"' -f4)
        
        if [[ -n "$self_name" ]]; then
            printf 'connected:Tailscale (%s)' "$self_name"
        else
            printf 'connected:Tailscale'
        fi
        return 0
    fi
    
    return 1
}

# Check OpenVPN connection
check_openvpn() {
    # Check for running openvpn process
    if pgrep -x "openvpn" &>/dev/null; then
        # Try to get config name from process
        local config
        config=$(ps aux | grep "[o]penvpn.*--config" | grep -o -- '--config [^ ]*' | head -1 | awk '{print $2}')
        
        if [[ -n "$config" ]]; then
            local name
            name=$(basename "$config" .ovpn 2>/dev/null || basename "$config" .conf 2>/dev/null)
            printf 'connected:OpenVPN (%s)' "$name"
        else
            printf 'connected:OpenVPN'
        fi
        return 0
    fi
    
    return 1
}

# Check macOS system VPN
check_macos_vpn() {
    is_macos || return 1
    
    # Use scutil to check VPN status - only truly connected VPNs show "*" prefix
    local vpn_status
    vpn_status=$(scutil --nc list 2>/dev/null | grep -E "^\*.*Connected")
    
    if [[ -n "$vpn_status" ]]; then
        # Extract VPN name
        local vpn_name
        vpn_name=$(echo "$vpn_status" | sed 's/.*"\([^"]*\)".*/\1/')
        printf 'connected:%s' "$vpn_name"
        return 0
    fi
    
    # Note: We don't check utun interfaces because macOS creates multiple utun
    # interfaces by default for various system services (Back to My Mac, etc.)
    # This would cause false positives
    
    return 1
}

# Check Linux NetworkManager VPN
check_networkmanager_vpn() {
    command -v nmcli &>/dev/null || return 1
    
    local vpn_conn
    vpn_conn=$(nmcli -t -f NAME,TYPE,STATE connection show --active 2>/dev/null | grep ":vpn:activated" | cut -d: -f1 | head -1)
    
    if [[ -n "$vpn_conn" ]]; then
        printf 'connected:%s' "$vpn_conn"
        return 0
    fi
    
    return 1
}

# Check for tun/tap interfaces (generic VPN detection)
check_tun_interface() {
    local tun_interfaces
    
    if is_linux; then
        tun_interfaces=$(ip link show 2>/dev/null | grep -E "tun[0-9]+|tap[0-9]+" | wc -l)
    else
        tun_interfaces=$(ifconfig 2>/dev/null | grep -E "^tun[0-9]+|^tap[0-9]+" | wc -l)
    fi
    
    if [[ "$tun_interfaces" -gt 0 ]]; then
        printf 'connected:VPN'
        return 0
    fi
    
    return 1
}

# Main function to get VPN status
get_vpn_status() {
    # Check various VPN types in order of specificity
    check_cloudflare_warp && return 0
    check_forticlient && return 0
    check_tailscale && return 0
    check_wireguard && return 0
    check_openvpn && return 0
    
    if is_macos; then
        check_macos_vpn && return 0
    else
        check_networkmanager_vpn && return 0
    fi
    
    # Generic check as fallback
    check_tun_interface && return 0
    
    # No VPN connected
    printf 'disconnected:'
    return 0
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
    
    local status="${content%%:*}"
    
    if [[ "$status" == "disconnected" ]]; then
        icon=$(get_cached_option "@theme_plugin_vpn_icon_disconnected" "$PLUGIN_VPN_ICON_DISCONNECTED")
        accent=$(get_cached_option "@theme_plugin_vpn_disconnected_accent_color" "")
        accent_icon=$(get_cached_option "@theme_plugin_vpn_disconnected_accent_color_icon" "")
    else
        # Connected - use default or custom connected colors
        accent=$(get_cached_option "@theme_plugin_vpn_connected_accent_color" "")
        accent_icon=$(get_cached_option "@theme_plugin_vpn_connected_accent_color_icon" "")
    fi
    
    build_display_info "$show" "$accent" "$accent_icon" "$icon"
}

# =============================================================================
# Main Plugin Logic
# =============================================================================

load_plugin() {
    # Check cache first
    local cached_value
    if cached_value=$(cache_get "$VPN_CACHE_KEY" "$VPN_CACHE_TTL"); then
        printf '%s' "$cached_value"
        return 0
    fi
    
    local vpn_info
    vpn_info=$(get_vpn_status)
    
    local status vpn_name
    status="${vpn_info%%:*}"
    vpn_name="${vpn_info#*:}"
    
    local show_when_disconnected show_name max_length
    show_when_disconnected=$(get_tmux_option "@theme_plugin_vpn_show_when_disconnected" "$PLUGIN_VPN_SHOW_WHEN_DISCONNECTED")
    show_name=$(get_tmux_option "@theme_plugin_vpn_show_name" "$PLUGIN_VPN_SHOW_NAME")
    max_length=$(get_tmux_option "@theme_plugin_vpn_max_length" "$PLUGIN_VPN_MAX_LENGTH")
    
    local result
    
    if [[ "$status" == "disconnected" ]]; then
        if [[ "$show_when_disconnected" != "true" ]]; then
            # Return empty to hide the plugin
            cache_set "$VPN_CACHE_KEY" ""
            return 0
        fi
        result="disconnected:OFF"
    else
        if [[ "$show_name" == "true" ]] && [[ -n "$vpn_name" ]]; then
            # Truncate name if too long
            if [[ ${#vpn_name} -gt $max_length ]]; then
                vpn_name="${vpn_name:0:$((max_length-1))}…"
            fi
            result="connected:$vpn_name"
        else
            result="connected:VPN"
        fi
    fi
    
    cache_set "$VPN_CACHE_KEY" "$result"
    printf '%s' "$result"
}

# Only run if executed directly (not sourced)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    # Output only the display part (after the colon)
    output=$(load_plugin)
    printf '%s' "${output#*:}"
fi
