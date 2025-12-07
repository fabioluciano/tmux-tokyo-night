#!/usr/bin/env bash
# Smart Card/Hardware Key interaction status plugin
# Dependencies: Cross-platform (gpg-agent, ssh-agent, PIV monitoring - no system logs)
# Supports: YubiKey, SoloKeys, Nitrokey, and other PIV/OpenPGP smart cards

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck source=src/plugin_bootstrap.sh
. "$ROOT_DIR/../plugin_bootstrap.sh"

# =============================================================================
# Plugin Configuration
# =============================================================================

# Initialize cache (DRY - sets CACHE_KEY and CACHE_TTL automatically)
plugin_init "smartkey"

# =============================================================================
# Plugin Interface Implementation
# =============================================================================

# Function to inform the plugin type to the renderer
plugin_get_type() {
    printf 'conditional'
}

# Plugin settings (from defaults.sh)
PLUGIN_CACHE_TTL=$(get_plugin_option "cache_ttl" "$POWERKIT_PLUGIN_SMARTKEY_CACHE_TTL")
# Use shorter cache for more responsive detection during touch operations
if [[ -z "$POWERKIT_PLUGIN_CACHE_TTL" ]]; then
    PLUGIN_CACHE_TTL=1
fi

# =============================================================================
# Smart Card/Hardware Key Detection - Cross-Platform
# =============================================================================

detect_smartkey_waiting() {
    local waiting_status="false"
    local detection_method=""
    
    # Method 1: Check for GPG operations waiting for touch (most specific)
    if [[ "$waiting_status" == "false" ]]; then
        if check_gpg_touch_waiting; then
            waiting_status="true"
            detection_method="gpg_touch"
        fi
    fi
    
    # Method 2: Check for active GPG operations that might be waiting for touch
    if [[ "$waiting_status" == "false" ]]; then
        if check_gpg_operations; then
            waiting_status="true"
            detection_method="gpg"
        fi
    fi
    
    # Method 3: Check GPG agent status (for OpenPGP smart cards)
    # Check for pinentry process (user interaction)
    if [[ "$waiting_status" == "false" ]] && check_pinentry_processes; then
        if check_gpg_waiting; then
            waiting_status="true"
            detection_method="gpg_pin"
        fi
    fi
    
    # Method 4: Check SSH agent for hardware key operations
    if [[ "$waiting_status" == "false" ]]; then
        if check_ssh_smartkey_waiting; then
            waiting_status="true"
            detection_method="ssh"
        fi
    fi
    
    # Method 5: Check PIV/PKCS11 operations (smart card interface)
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

# Check for active GPG operations that might be waiting for touch
check_gpg_operations() {
    # Check for GPG processes that are not gpg-agent (active operations)
    if ps aux | grep -E "gpg[[:space:]]|gpg2[[:space:]]" | grep -v "gpg-agent" | grep -q -v "grep"; then
        return 0
    fi
    return 1
}

# Check for GPG operations in touch-waiting state
check_gpg_touch_waiting() {
    # Check if gpg-agent is actively waiting for card touch
    if command -v gpg-connect-agent >/dev/null 2>&1; then
        # Quick check for card operations
        local agent_status
        agent_status=$(timeout 1 gpg-connect-agent 'KEYINFO --list' /bye 2>/dev/null | grep -i "card\|yubikey" 2>/dev/null)
        if [[ -n "$agent_status" ]]; then
            # Card detected, check if there are active operations
            if check_gpg_operations; then
                return 0
            fi
        fi
    fi
    
    # Alternative: Check for scdaemon activity (smart card daemon)
    if pgrep -f "scdaemon" >/dev/null 2>&1; then
        # scdaemon is running, check if it's actively processing
        local scd_activity
        scd_activity=$(ps -p "$(pgrep -f 'scdaemon' | head -1)" -o %cpu= 2>/dev/null | tr -d ' ' | cut -d. -f1)
        if [[ -n "$scd_activity" && "$scd_activity" =~ ^[0-9]+$ && "$scd_activity" -gt 0 ]]; then
            return 0
        fi
    fi
    
    return 1
}

# Check for pinentry processes (cross-platform)
check_pinentry_processes() {
    # Try different approaches for finding pinentry
    if command -v pgrep >/dev/null 2>&1; then
        # Use pgrep if available
        if pgrep -f "pinentry" >/dev/null 2>&1; then
            return 0
        fi
    fi
    
    # Fallback: use ps to find pinentry processes
    if ps aux | grep "pinentry" | grep -v "grep" | grep -q .; then
        return 0
    fi
    
    return 1
}

# Check if services are waiting for smart card/hardware key interaction
check_waiting_services() {
    # This method should only return true if there's an active operation waiting for touch
    # Simply having background services running (like gpg-agent) is not sufficient
    
    # Check for processes actively waiting for user interaction
    if check_pinentry_processes; then
        return 0
    fi
    
    # Check for active GPG operations
    if check_gpg_operations; then
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

get_cached_or_fetch() {
    local cached_value
    if cached_value=$(cache_get "$CACHE_KEY" "$CACHE_TTL"); then
        echo "$cached_value"
    else
        local result
        result=$(detect_smartkey_waiting)
        cache_set "$CACHE_KEY" "$result"
        echo "$result"
    fi
}

# =============================================================================
# Plugin Display Info for Render System
# =============================================================================

# This function is called by plugin_helpers.sh to get display decisions
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
        local waiting_accent=$(get_plugin_option "waiting_accent_color" "$POWERKIT_PLUGIN_SMARTKEY_WAITING_ACCENT_COLOR")
        local waiting_accent_icon=$(get_plugin_option "waiting_accent_color_icon" "$POWERKIT_PLUGIN_SMARTKEY_WAITING_ACCENT_COLOR_ICON")
        local waiting_icon=$(get_plugin_option "waiting_icon" "$POWERKIT_PLUGIN_SMARTKEY_WAITING_ICON")
        echo "1:$waiting_accent:$waiting_accent_icon:$waiting_icon"
    elif [[ "$(get_plugin_option "show_when_inactive" "$POWERKIT_PLUGIN_SMARTKEY_SHOW_WHEN_INACTIVE")" == "true" ]]; then
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
            "gpg_touch") printf 'TOUCH' ;;
            "gpg")       printf 'TOUCH GPG' ;;
            "gpg_pin")   printf 'PIN GPG' ;;
            "ssh")       printf 'TOUCH SSH' ;;
            "piv")       printf 'TOUCH PIV' ;;
            "ykman")     printf 'TOUCH KEY' ;;
            "logs")      printf 'TOUCH' ;;
            *)           printf 'TOUCH' ;;
        esac
    elif [[ "$(get_plugin_option "show_when_inactive" "$POWERKIT_PLUGIN_SMARTKEY_SHOW_WHEN_INACTIVE")" == "true" ]]; then
        # Show key icon when inactive but plugin visible
        printf 'KEY'
    fi
    # When not waiting and show_when_inactive=false, return nothing
}

# Only run if executed directly (not sourced)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    # If running standalone (for testing), use simple defaults
    if ! command -v get_tmux_option >/dev/null 2>&1; then
        # Simple standalone test
        result=$(detect_smartkey_waiting)
        waiting_status="${result%:*}"
        detection_method="${result#*:}"
        
        if [[ "$waiting_status" == "true" ]]; then
            case "$detection_method" in
                "gpg")     printf 'TOUCH GPG' ;;
                "ssh")     printf 'TOUCH SSH' ;;
                "piv")     printf 'TOUCH PIV' ;;
                *)         printf 'TOUCH' ;;
            esac
        fi
    else
        load_plugin
    fi
fi