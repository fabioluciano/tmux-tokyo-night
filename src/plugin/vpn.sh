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
#   @theme_plugin_vpn_show_ip              - Show VPN IP instead of name (default: false)
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
    # Check if warp-cli is available
    if ! command -v warp-cli >/dev/null 2>&1; then
        return 2  # Command not found
    fi
    local status
    status=$(warp-cli status 2>/dev/null) || return 1
    
    if echo "$status" | grep -q "Connected"; then
        printf 'connected:Cloudflare WARP'
        return 0
    fi
    
    return 1
}

# Check FortiClient VPN connection
check_forticlient() {
    local vpn_name vpn_ip interface_name status
    
    # Method 1: Use FortiClient CLI (best method - works on Linux/macOS)
    if status=$(forticlient vpn status 2>/dev/null || forticlient status 2>/dev/null); then
        if echo "$status" | grep -q "Connected"; then
            # Extract VPN name
            vpn_name=$(echo "$status" | grep "VPN name:" | sed 's/.*VPN name: //' | sed 's/^[[:space:]]*//')
            # Extract IP
            vpn_ip=$(echo "$status" | grep "IP:" | sed 's/.*IP: //' | sed 's/^[[:space:]]*//')
            
            # Return both name and IP for later selection
            printf 'connected:%s|%s' "$vpn_name" "$vpn_ip"
            return 0
        fi
        return 1
    fi
    
    # Method 2: Check for openfortivpn CLI process (avoid command -v)
    if pgrep -x "openfortivpn" &>/dev/null; then
        printf 'connected:FortiVPN|'
        return 0
    fi
    
    # Method 3: Check for FortiClient process on macOS
    if is_macos; then
        if pgrep -f "FortiClient" &>/dev/null; then
            local forti_status
            forti_status=$(scutil --nc list 2>/dev/null | grep -i "forti" | grep -E "^\*.*Connected")
            if [[ -n "$forti_status" ]]; then
                vpn_name=${forti_status##*\"}
                vpn_name=${vpn_name%%\"*}
                printf 'connected:%s|' "$vpn_name"
                return 0
            fi
            
            if pgrep -f "FortiTray" &>/dev/null && ifconfig 2>/dev/null | grep -q "ppp0"; then
                printf 'connected:FortiClient|'
                return 0
            fi
        fi
    fi
    
    # Method 4: Check for FortiClient on Linux (fallback)
    if is_linux; then
        # Check for FortiClient VPN interfaces (fct* or fctvpn*)
        local forti_interfaces
        forti_interfaces=$(ip link show 2>/dev/null | grep -oE "fct[a-z0-9]+|fctvpn[a-z0-9]+")
        
        if [[ -n "$forti_interfaces" ]]; then
            interface_name=$(echo "$forti_interfaces" | head -1)
            
            # Get VPN IP address
            vpn_ip=$(ip addr show "$interface_name" 2>/dev/null | grep -oE "inet [0-9]+\.[0-9]+\.[0-9]+\.[0-9]+" | awk '{print $2}')
            
            printf 'connected:FortiClient|%s' "$vpn_ip"
            return 0
        fi
        
        # Check for ppp interface
        if pgrep -f "forticlient" &>/dev/null || pgrep -f "fortisslvpn" &>/dev/null; then
            if ip link show ppp0 &>/dev/null 2>&1; then
                printf 'connected:FortiClient|'
                return 0
            fi
        fi
    fi
    
    return 1
}

# Check WireGuard connection
check_wireguard() {
    local interface vpn_ip
    
    # Try to get interface directly (faster than command -v + wg)
    interface=$(wg show interfaces 2>/dev/null | head -1) || return 1
    
    if [[ -n "$interface" ]]; then
        # Get IP address from interface
        if is_linux; then
            vpn_ip=$(ip addr show "$interface" 2>/dev/null | grep -oE "inet [0-9]+\.[0-9]+\.[0-9]+\.[0-9]+" | awk '{print $2}')
        else
            vpn_ip=$(ifconfig "$interface" 2>/dev/null | grep -oE "inet [0-9]+\.[0-9]+\.[0-9]+\.[0-9]+" | awk '{print $2}')
        fi
        
        printf 'connected:WireGuard|%s' "$vpn_ip"
        return 0
    fi
    
    return 1
}

# Check Tailscale connection
check_tailscale() {
    local status
    
    # Try tailscale command directly (faster than command -v check first)
    status=$(tailscale status --json 2>/dev/null) || return 1
    
    
    if [[ -z "$status" ]]; then
        return 1
    fi
    
    # Check if connected (BackendState should be "Running")
    local backend_state
    backend_state=$(echo "$status" | grep -o '"BackendState":"[^"]*"' | cut -d'"' -f4)
    
    if [[ "$backend_state" == "Running" ]]; then
        # Get current exit node or hostname
        local self_name vpn_ip
        self_name=$(echo "$status" | grep -o '"Self":{[^}]*"HostName":"[^"]*"' | grep -o '"HostName":"[^"]*"' | cut -d'"' -f4)
        
        # Try to get Tailscale IP
        vpn_ip=$(tailscale ip -4 2>/dev/null | head -1)
        
        if [[ -n "$self_name" ]]; then
            printf 'connected:%s|%s' "$self_name" "$vpn_ip"
        else
            printf 'connected:Tailscale|%s' "$vpn_ip"
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
        local config name vpn_ip tun_if
        config=$(pgrep -a openvpn | grep -o -- '--config [^ ]*' | head -1 | awk '{print $2}')
        
        if [[ -n "$config" ]]; then
            name=$(basename "$config" .ovpn 2>/dev/null || basename "$config" .conf 2>/dev/null)
        else
            name="OpenVPN"
        fi
        
        # Try to find tun interface and get IP
        if is_linux; then
            tun_if=$(ip link show 2>/dev/null | grep -oE "tun[0-9]+" | head -1)
            if [[ -n "$tun_if" ]]; then
                vpn_ip=$(ip addr show "$tun_if" 2>/dev/null | grep -oE "inet [0-9]+\.[0-9]+\.[0-9]+\.[0-9]+" | awk '{print $2}')
            fi
        else
            tun_if=$(ifconfig 2>/dev/null | grep -oE "^tun[0-9]+" | head -1)
            if [[ -n "$tun_if" ]]; then
                vpn_ip=$(ifconfig "$tun_if" 2>/dev/null | grep -oE "inet [0-9]+\.[0-9]+\.[0-9]+\.[0-9]+" | awk '{print $2}')
            fi
        fi
        
        printf 'connected:%s|%s' "$name" "$vpn_ip"
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
        local vpn_name vpn_ip
        vpn_name=${vpn_status##*\"}
        vpn_name=${vpn_name%%\"*}
        
        # Try to get IP from first utun interface (VPN usually uses utun)
        local utun_if
        utun_if=$(ifconfig 2>/dev/null | grep -oE "^utun[0-9]+" | head -1)
        if [[ -n "$utun_if" ]]; then
            vpn_ip=$(ifconfig "$utun_if" 2>/dev/null | grep -oE "inet [0-9]+\.[0-9]+\.[0-9]+\.[0-9]+" | awk '{print $2}')
        fi
        
        printf 'connected:%s|%s' "$vpn_name" "$vpn_ip"
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
    
    local vpn_conn vpn_ip vpn_device
    vpn_conn=$(nmcli -t -f NAME,TYPE,STATE connection show --active 2>/dev/null | grep ":vpn:activated" | cut -d: -f1 | head -1)
    
    if [[ -n "$vpn_conn" ]]; then
        # Try to get VPN device/interface
        vpn_device=$(nmcli -t -f NAME,DEVICE connection show --active 2>/dev/null | grep "^$vpn_conn:" | cut -d: -f2)
        
        if [[ -n "$vpn_device" ]]; then
            vpn_ip=$(ip addr show "$vpn_device" 2>/dev/null | grep -oE "inet [0-9]+\.[0-9]+\.[0-9]+\.[0-9]+" | awk '{print $2}')
        fi
        
        printf 'connected:%s|%s' "$vpn_conn" "$vpn_ip"
        return 0
    fi
    
    return 1
}

# Check for tun/tap interfaces (generic VPN detection)
check_tun_interface() {
    local vpn_ip
    
    if is_linux; then
        # Check for standard tun/tap interfaces
        local tun_if
        tun_if=$(ip link show 2>/dev/null | grep -oE "tun[0-9]+|tap[0-9]+" | head -1)
        
        if [[ -n "$tun_if" ]]; then
            # Get VPN IP address
            vpn_ip=$(ip addr show "$tun_if" 2>/dev/null | grep -oE "inet [0-9]+\.[0-9]+\.[0-9]+\.[0-9]+" | awk '{print $2}')
            printf 'connected:VPN|%s' "$vpn_ip"
            return 0
        fi
        
        # Check for POINTOPOINT interfaces (characteristic of VPN tunnels)
        # but exclude known non-VPN interfaces and FortiClient (already checked above)
        local ppp_interfaces
        ppp_interfaces=$(ip addr show 2>/dev/null | grep -E "^[0-9]+: [a-z0-9]+:.*POINTOPOINT" | grep -vE "lo:|docker|fct|fctvpn" | awk -F': ' '{print $2}')
        
        if [[ -n "$ppp_interfaces" ]]; then
            local interface_name
            interface_name=$(echo "$ppp_interfaces" | head -1)
            # Get VPN IP address
            vpn_ip=$(ip addr show "$interface_name" 2>/dev/null | grep -oE "inet [0-9]+\.[0-9]+\.[0-9]+\.[0-9]+" | awk '{print $2}')
            printf 'connected:VPN|%s' "$vpn_ip"
            return 0
        fi
    else
        local tun_if
        tun_if=$(ifconfig 2>/dev/null | grep -oE "^tun[0-9]+|^tap[0-9]+" | head -1)
        
        if [[ -n "$tun_if" ]]; then
            vpn_ip=$(ifconfig "$tun_if" 2>/dev/null | grep -oE "inet [0-9]+\.[0-9]+\.[0-9]+\.[0-9]+" | awk '{print $2}')
            printf 'connected:VPN|%s' "$vpn_ip"
            return 0
        fi
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
    
    local status vpn_data vpn_name vpn_ip
    status="${vpn_info%%:*}"
    vpn_data="${vpn_info#*:}"
    
    # Parse name|ip format
    vpn_name="${vpn_data%%|*}"
    vpn_ip="${vpn_data#*|}"
    
    local show_when_disconnected show_name show_ip max_length
    show_when_disconnected=$(get_tmux_option "@theme_plugin_vpn_show_when_disconnected" "$PLUGIN_VPN_SHOW_WHEN_DISCONNECTED")
    show_name=$(get_tmux_option "@theme_plugin_vpn_show_name" "$PLUGIN_VPN_SHOW_NAME")
    show_ip=$(get_tmux_option "@theme_plugin_vpn_show_ip" "false")
    max_length=$(get_tmux_option "@theme_plugin_vpn_max_length" "$PLUGIN_VPN_MAX_LENGTH")
    
    local result display_text
    
    if [[ "$status" == "disconnected" ]]; then
        if [[ "$show_when_disconnected" != "true" ]]; then
            # Return empty to hide the plugin
            cache_set "$VPN_CACHE_KEY" ""
            return 0
        fi
        result="disconnected:OFF"
    else
        # Decide what to show: IP or name
        if [[ "$show_ip" == "true" ]] && [[ -n "$vpn_ip" ]]; then
            display_text="$vpn_ip"
        elif [[ "$show_name" == "true" ]] && [[ -n "$vpn_name" ]]; then
            display_text="$vpn_name"
        else
            display_text="VPN"
        fi
        
        # Truncate if too long
        if [[ ${#display_text} -gt $max_length ]]; then
            display_text="${display_text:0:$((max_length-1))}…"
        fi
        
        result="connected:$display_text"
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
