#!/usr/bin/env bash
# Smart Card/Hardware Key interaction status plugin
# Dependencies: Cross-platform (gpg-agent, ssh-agent, PIV monitoring - no system logs)
# Supports: YubiKey, SoloKeys, Nitrokey, and other PIV/OpenPGP smart cards

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck source=src/defaults.sh
. "$ROOT_DIR/../defaults.sh"
# shellcheck source=src/utils.sh
. "$ROOT_DIR/../utils.sh"

# =============================================================================
# Plugin Configuration
# =============================================================================

# Get plugin options with defaults
get_plugin_option() {
    local option="$1"
    local default="$2"
    get_tmux_option "@theme_plugin_smartkey_$option" "$default"
}

# Plugin variables for theme system
# shellcheck disable=SC2034
plugin_smartkey_icon=$(get_plugin_option "icon" "$PLUGIN_SMARTKEY_ICON")
# shellcheck disable=SC2034
plugin_smartkey_accent_color=$(get_plugin_option "accent_color" "$PLUGIN_SMARTKEY_ACCENT_COLOR")
# shellcheck disable=SC2034
plugin_smartkey_accent_color_icon=$(get_plugin_option "accent_color_icon" "$PLUGIN_SMARTKEY_ACCENT_COLOR_ICON")

export plugin_smartkey_icon plugin_smartkey_accent_color plugin_smartkey_accent_color_icon

# =============================================================================
# Plugin Interface Implementation
# =============================================================================

# Function to inform the plugin type to the renderer
plugin_get_type() {
    printf 'conditional'
}

# Plugin settings (from defaults.sh)
PLUGIN_CACHE_TTL=$(get_plugin_option "cache_ttl" "$PLUGIN_SMARTKEY_CACHE_TTL")

# =============================================================================
# Smart Card/Hardware Key Detection - Cross-Platform
# =============================================================================

detect_smartkey_waiting() {
    local waiting_status="false"
    local detection_method=""
    
    # Method 1: Check for hardware key operations (ykman, etc.)
    # Note: Specific tools only show if hardware key is connected, not waiting for touch
    # We rely on more specific detection methods below
    
    # Method 2: Check GPG agent status (for OpenPGP smart cards)
    # Only check if there's an active pinentry process (user interaction)
    if [[ "$waiting_status" == "false" ]] && pgrep -f "pinentry" >/dev/null 2>&1; then
        if check_gpg_waiting; then
            waiting_status="true"
            detection_method="gpg"
        fi
    fi
    
    # Method 3: Check SSH agent for hardware key operations
    if [[ "$waiting_status" == "false" ]]; then
        if check_ssh_smartkey_waiting; then
            waiting_status="true"
            detection_method="ssh"
        fi
    fi
    
    # Method 4: Check PIV/PKCS11 operations (smart card interface)
    if [[ "$waiting_status" == "false" ]]; then
        if check_piv_waiting; then
            waiting_status="true"
            detection_method="piv"
        fi
    fi
    
    # Method 5: System logs disabled (unreliable, especially on macOS)
    # Logs generate too many false positives and are not trustworthy
    
    echo "${waiting_status}:${detection_method}"
}

# Check if services are waiting for smart card/hardware key interaction
check_waiting_services() {
    # This method should only return true if there's an active operation waiting for touch
    # Simply having background services running (like gpg-agent) is not sufficient
    
    # Check for processes actively waiting for user interaction
    if pgrep -f "pinentry" >/dev/null 2>&1; then
        return 0
    fi
    
    # Check for SSH processes in authentication state
    if ps aux | grep "ssh " | grep -v "grep\|sshd\|ssh-agent" | grep -q -E "git@|authenticat"; then
        return 0
    fi
    
    return 1
}

# Check GPG agent for waiting operations
check_gpg_waiting() {
    # Only check for active pinentry process (password/touch prompt)
    if pgrep -f "pinentry" >/dev/null 2>&1; then
        return 0
    fi
    
    # Check for GPG operations specifically waiting for card touch
    if command -v gpg-connect-agent >/dev/null 2>&1; then
        local gpg_status
        gpg_status=$(timeout 2 gpg-connect-agent 'SCD SERIALNO' /bye 2>/dev/null)
        if [[ $? -eq 0 && "$gpg_status" =~ "touch.*required|waiting.*touch" ]]; then
            return 0
        fi
    fi
    
    return 1
}

# Check SSH agent for smart card/hardware key operations
check_ssh_smartkey_waiting() {
    # SSH detection disabled - too many false positives
    # Only pinentry-based detection is reliable for hardware key touch operations
    return 1
}

# Check PIV (Personal Identity Verification) operations
check_piv_waiting() {
    # Check for PKCS11 operations
    if command -v pkcs11-tool >/dev/null 2>&1; then
        local slots
        slots=$(pkcs11-tool --list-slots 2>/dev/null)
        if [[ $? -eq 0 && "$slots" =~ "Yubico|SoloKeys|Nitrokey|OpenPGP|PIV" ]]; then
            # Smart card detected in PKCS11, check for active operations
            if pgrep -f "pkcs11" >/dev/null 2>&1; then
                return 0
            fi
        fi
    fi
    
    # Check pcscd (PC/SC daemon) activity
    if pgrep -f "pcscd" >/dev/null 2>&1; then
        local pcscd_activity first_pcscd_pid
        first_pcscd_pid=$(pgrep -f "pcscd" | head -1 2>/dev/null)
        if [[ -n "$first_pcscd_pid" ]]; then
            pcscd_activity=$(ps -p "$first_pcscd_pid" -o %cpu= 2>/dev/null | tr -d ' ' | cut -d. -f1)
            if [[ -n "$pcscd_activity" && "$pcscd_activity" =~ ^[0-9]+$ && "$pcscd_activity" -gt 3 ]]; then
                return 0
            fi
        fi
    fi
    
    return 1
}

# System logs method removed - unreliable and causes false positives
# Use more specific detection methods instead (GPG, SSH, PIV)

# =============================================================================
# Cache Management
# =============================================================================

get_cache_file() {
    local cache_dir="${XDG_CACHE_HOME:-$HOME/.cache}/tmux-tokyo-night"
    mkdir -p "$cache_dir" 2>/dev/null
    echo "$cache_dir/smartkey.cache"
}

is_cache_valid() {
    local cache_file="$1"
    local ttl="$2"
    
    if [[ -f "$cache_file" ]]; then
        local cache_time current_time
        cache_time=$(stat -c %Y "$cache_file" 2>/dev/null || stat -f %m "$cache_file" 2>/dev/null || echo 0)
        current_time=$(date +%s)
        
        if [[ $((current_time - cache_time)) -lt $ttl ]]; then
            return 0
        fi
    fi
    return 1
}

get_cached_or_fetch() {
    local cache_file
    cache_file=$(get_cache_file)
    
    if is_cache_valid "$cache_file" "$PLUGIN_CACHE_TTL"; then
        cat "$cache_file"
    else
        local result
        result=$(detect_smartkey_waiting)
        echo "$result" > "$cache_file"
        echo "$result"
    fi
}

# =============================================================================
# Plugin Display Info for Render System
# =============================================================================

# This function is called by render_plugins.sh to get display decisions
# Output format: "show:accent:accent_icon:icon"
plugin_get_display_info() {
    local _content="$1"
    
    local status_result waiting_status detection_method
    status_result=$(get_cached_or_fetch)
    waiting_status="${status_result%:*}"
    detection_method="${status_result#*:}"
    
    # Show when smart card/hardware key is waiting for interaction
    if [[ "$waiting_status" == "true" ]]; then
        # Waiting for touch - yellow/orange colors with special icon
        local waiting_accent=$(get_plugin_option "waiting_accent_color" "$PLUGIN_SMARTKEY_WAITING_ACCENT_COLOR")
        local waiting_accent_icon=$(get_plugin_option "waiting_accent_color_icon" "$PLUGIN_SMARTKEY_WAITING_ACCENT_COLOR_ICON")
        local waiting_icon=$(get_plugin_option "waiting_icon" "$PLUGIN_SMARTKEY_WAITING_ICON")
        echo "1:$waiting_accent:$waiting_accent_icon:$waiting_icon"
    elif [[ "$(get_plugin_option "show_when_inactive" "$PLUGIN_SMARTKEY_SHOW_WHEN_INACTIVE")" == "true" ]]; then
        # Show inactive state if configured
        echo "1:$plugin_smartkey_accent_color:$plugin_smartkey_accent_color_icon:$plugin_smartkey_icon"
    else
        # Don't show when not waiting
        echo "0:::"
    fi
}

# =============================================================================
# Main Plugin Entry Points
# =============================================================================

load_plugin() {
    local status_result waiting_status detection_method
    status_result=$(get_cached_or_fetch)
    waiting_status="${status_result%:*}"
    detection_method="${status_result#*:}"
    
    # Show different text based on smart card/hardware key state
    if [[ "$waiting_status" == "true" ]]; then
        case "$detection_method" in
            "gpg")     printf 'TOUCH GPG' ;;
            "ssh")     printf 'TOUCH SSH' ;;
            "piv")     printf 'TOUCH PIV' ;;
            "ykman")   printf 'TOUCH KEY' ;;
            "logs")    printf 'TOUCH' ;;
            *)         printf 'TOUCH' ;;
        esac
    elif [[ "$(get_plugin_option "show_when_inactive" "$PLUGIN_SMARTKEY_SHOW_WHEN_INACTIVE")" == "true" ]]; then
        # Show key icon when inactive but plugin visible
        printf 'KEY'
    fi
    # When not waiting and show_when_inactive=false, return nothing
}

# Only run if executed directly (not sourced)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    load_plugin
fi