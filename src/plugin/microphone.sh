#!/usr/bin/env bash
# =============================================================================
# Plugin: microphone
# Description: Display microphone activity status (active/inactive)
# Dependencies: Cross-platform (macOS system processes, Linux ALSA/PulseAudio)
# =============================================================================
#
# Configuration options:
#   @theme_plugin_microphone_icon                 - Microphone icon (default: 󰍬)
#   @theme_plugin_microphone_muted_icon           - Muted microphone icon (default: 󰍭)
#   @theme_plugin_microphone_accent_color         - Accent color (default: blue7)
#   @theme_plugin_microphone_accent_color_icon    - Icon accent color (default: blue0)
#   @theme_plugin_microphone_cache_ttl            - Cache time in seconds (default: 1)
#
# Example configurations:
#   # Custom icons
#   set -g @theme_plugin_microphone_icon ""
#   set -g @theme_plugin_microphone_muted_icon ""
#   
#   # Custom cache time
#   set -g @theme_plugin_microphone_cache_ttl "2"
#
# =============================================================================

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck source=src/defaults.sh
source "$ROOT_DIR/../defaults.sh"
# shellcheck source=src/utils.sh
source "$ROOT_DIR/../utils.sh"

# Plugin Configuration

# shellcheck disable=SC2034
plugin_microphone_icon=$(get_tmux_option "@theme_plugin_microphone_icon" "$PLUGIN_MICROPHONE_ICON")
# shellcheck disable=SC2034
plugin_microphone_accent_color=$(get_tmux_option "@theme_plugin_microphone_accent_color" "$PLUGIN_MICROPHONE_ACCENT_COLOR")
# shellcheck disable=SC2034
plugin_microphone_accent_color_icon=$(get_tmux_option "@theme_plugin_microphone_accent_color_icon" "$PLUGIN_MICROPHONE_ACCENT_COLOR_ICON")

# Cache TTL in seconds (default: 1 second)
CACHE_TTL=$(get_tmux_option "@theme_plugin_microphone_cache_ttl" "$PLUGIN_MICROPHONE_CACHE_TTL")
CACHE_KEY="microphone"

export plugin_microphone_icon plugin_microphone_accent_color plugin_microphone_accent_color_icon

# Microphone Control Functions

# Toggle microphone mute state
toggle_microphone_mute() {
    if is_linux; then
        if command -v pactl >/dev/null 2>&1; then
                # Get default source
                local default_source
                default_source=$(pactl get-default-source 2>/dev/null)
                
                if [[ -n "$default_source" ]]; then
                    # Toggle mute state
                    if pactl set-source-mute "$default_source" toggle 2>/dev/null; then
                        # Clear cache to force status update
                        local cache_dir="${XDG_CACHE_HOME:-$HOME/.cache}/tmux-tokyo-night"
                        rm -f "${cache_dir}/microphone.cache" 2>/dev/null
                        
                        # Get new state for notification
                        local is_muted
                        if pactl get-source-mute "$default_source" 2>/dev/null | grep -q "yes"; then
                            is_muted="muted"
                        else
                            is_muted="unmuted"
                        fi
                        
                        # Show notification
                        tmux display-message "Microphone $is_muted" 2>/dev/null || true
                        
                        # Refresh tmux status bar
                        tmux refresh-client -S 2>/dev/null || true
                    else
                        tmux display-message "Failed to toggle microphone" 2>/dev/null || true
                    fi
                else
                    tmux display-message "No microphone found" 2>/dev/null || true
                fi
            else
                tmux display-message "pactl not found - PulseAudio required" 2>/dev/null || true
            fi
    elif is_macos; then
        tmux display-message "Microphone mute toggle not supported on macOS" 2>/dev/null || true
    else
        tmux display-message "Microphone mute toggle not supported on this platform" 2>/dev/null || true
    fi
}

# Setup keybindings for microphone mute toggle
setup_keybindings() {
    local mute_key
    
    # Get mute key binding
    mute_key=$(get_tmux_option "@theme_plugin_microphone_mute_key" "$PLUGIN_MICROPHONE_MUTE_KEY")
    
    # Only setup keybinding if key is defined
    if [[ -n "$mute_key" ]]; then
        # Use simple OS detection instead of get_os function
        local os_name
        os_name=$(uname -s)
        
        case "$os_name" in
            "Linux")
                if command -v pactl >/dev/null 2>&1; then
                    # Setup mute toggle keybinding - use absolute paths to avoid issues
                    local plugin_path="$ROOT_DIR/microphone.sh"
                    local defaults_path="$ROOT_DIR/../defaults.sh"
                    local utils_path="$ROOT_DIR/../utils.sh"
                    
                    tmux bind-key "$mute_key" run-shell "source '$defaults_path' && source '$utils_path' && source '$plugin_path' && toggle_microphone_mute" 2>/dev/null || true
                fi
                ;;
            "Darwin")
                # Could be extended in the future with macOS support
                ;;
        esac
    fi
}

# Plugin Interface Implementation

# Function to inform the plugin type to the renderer
plugin_get_type() {
    printf 'conditional'
}

# Plugin settings
PLUGIN_ICON="$PLUGIN_MICROPHONE_ICON"
PLUGIN_MUTED_ICON="$PLUGIN_MICROPHONE_MUTED_ICON"
PLUGIN_ACCENT_COLOR="$PLUGIN_MICROPHONE_ACCENT_COLOR"
PLUGIN_ACCENT_COLOR_ICON="$PLUGIN_MICROPHONE_ACCENT_COLOR_ICON"
PLUGIN_CACHE_TTL="$PLUGIN_MICROPHONE_CACHE_TTL"

# =============================================================================
# Microphone Detection - macOS
# =============================================================================

detect_microphone_usage_macos() {
    # Method 1: Check for processes that have active audio input sessions
    # This uses lsof to check for processes accessing the built-in microphone
    if command -v lsof >/dev/null 2>&1; then
        # Check for processes using audio input devices
        local mic_users
        mic_users=$(lsof 2>/dev/null | grep -E "Built-in Microph|coreaudiod.*Input" | grep -v coreaudiod | wc -l | tr -d ' ')
        if [[ "${mic_users:-0}" -gt 0 ]]; then
            echo "active"
            return
        fi
    fi
    
    # Method 2: Check if any process is actively recording audio
    # Use ps to find processes with high CPU that might be recording
    local high_cpu_audio_procs
    high_cpu_audio_procs=$(ps -eo pid,ppid,%cpu,comm | awk '$3 > 5 && $4 ~ /firefox|chrome|safari|zoom|teams|discord|obs/ {print $1}' | wc -l | tr -d ' ')
    if [[ "${high_cpu_audio_procs:-0}" -gt 0 ]]; then
        # Double check these processes are actually using audio
        local audio_active_procs
        audio_active_procs=$(ps -eo pid,ppid,%cpu,comm | awk '$3 > 10 && $4 ~ /firefox|chrome|safari/ {print $1}' | wc -l | tr -d ' ')
        if [[ "${audio_active_procs:-0}" -gt 0 ]]; then
            echo "active"
            return
        fi
    fi
    
    # Method 3: Simple fallback - disable for now to test basic functionality
    # For now, just return inactive unless we detect clear usage
    echo "inactive"
}

# =============================================================================
# Microphone Detection - Linux
# =============================================================================

detect_microphone_mute_status_linux() {
    # Check PulseAudio/PipeWire for mute status
    if command -v pactl >/dev/null 2>&1; then
        # Get the default source (microphone) and check if it's muted
        local default_source mute_status
        default_source=$(pactl get-default-source 2>/dev/null)
        if [[ -n "$default_source" ]]; then
            mute_status=$(pactl get-source-mute "$default_source" 2>/dev/null | grep -o "yes\|no")
            if [[ "$mute_status" == "yes" ]]; then
                echo "muted"
                return
            fi
        fi
    fi
    
    # Check ALSA mixer for mute status
    if command -v amixer >/dev/null 2>&1; then
        local capture_mute
        capture_mute=$(amixer get Capture 2>/dev/null | grep -o "\[off\]" | head -1)
        if [[ -n "$capture_mute" ]]; then
            echo "muted"
            return
        fi
    fi
    
    echo "unmuted"
}

detect_microphone_usage_linux() {
    # Method 1: Check PulseAudio/PipeWire for active recording sessions
    if command -v pactl >/dev/null 2>&1; then
        # Check for active source outputs (recording applications)
        if pactl list short source-outputs 2>/dev/null | grep -q .; then
            echo "active"
            return
        fi
    fi
    
    # Method 2: Check for actual recording processes (not system audio daemons)
    if command -v lsof >/dev/null 2>&1; then
        # Look for processes actively writing to capture devices, excluding system daemons
        local active_capture
        active_capture=$(lsof /dev/snd/* 2>/dev/null | grep -E "pcmC[0-9]+D[0-9]+c" | grep -v -E "(pipewire|wireplumb|pulseaudio)" | wc -l)
        if [[ "${active_capture:-0}" -gt 0 ]]; then
            echo "active"
            return
        fi
    fi
    
    # Method 3: Check common microphone applications (excluding system audio services)
    local mic_processes=("zoom" "teams" "discord" "skype" "obs" "audacity" "arecord" "ffmpeg" "vlc")
    for proc in "${mic_processes[@]}"; do
        if pgrep -x "$proc" >/dev/null 2>&1; then
            echo "active"
            return
        fi
    done
    
    echo "inactive"
}

# =============================================================================
# Microphone Detection - Cross-Platform Entry Point
# =============================================================================

detect_microphone_mute_status() {
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS: Use osascript to check microphone mute status
        if command -v osascript >/dev/null 2>&1; then
            local mute_status
            mute_status=$(osascript -e "input volume of (get volume settings)" 2>/dev/null | grep -o "0\|[1-9][0-9]*")
            if [[ "$mute_status" == "0" ]]; then
                echo "muted"
            else
                echo "unmuted"
            fi
        else
            echo "unmuted"
        fi
    elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
        detect_microphone_mute_status_linux
    else
        echo "unmuted"
    fi
}

detect_microphone_usage() {
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS: Microphone detection disabled due to privacy protections
        # The system's orange indicator cannot be reliably detected via shell scripts
        echo "inactive"
    elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
        detect_microphone_usage_linux
    else
        echo "inactive"
    fi
}

# =============================================================================
# Cache Management
# =============================================================================

get_cache_file() {
    echo "/tmp/tmux_microphone_status_$$"
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
        local usage_result mute_result
        usage_result=$(detect_microphone_usage)
        mute_result=$(detect_microphone_mute_status)
        local combined_result="${usage_result}:${mute_result}"
        echo "$combined_result" > "$cache_file"
        echo "$combined_result"
    fi
}

# =============================================================================
# Plugin Display Info for Render System
# =============================================================================

# This function is called by render_plugins.sh to get display decisions
# Output format: "show:accent:accent_icon:icon"
plugin_get_display_info() {
    local _content="$1"
    
    local status_result usage_status mute_status
    status_result=$(get_cached_or_fetch)
    usage_status="${status_result%:*}"
    mute_status="${status_result#*:}"
    
    # Show when microphone is active
    if [[ "$usage_status" == "active" ]]; then
        if [[ "$mute_status" == "muted" ]]; then
            # Muted microphone - red background, muted icon
            echo "1:$PLUGIN_MICROPHONE_MUTED_ACCENT_COLOR:$PLUGIN_MICROPHONE_MUTED_ACCENT_COLOR_ICON:$PLUGIN_MUTED_ICON"
        else
            # Active microphone - green background, normal icon
            echo "1:$PLUGIN_MICROPHONE_ACTIVE_ACCENT_COLOR:$PLUGIN_MICROPHONE_ACTIVE_ACCENT_COLOR_ICON:$PLUGIN_ICON"
        fi
    else
        # Don't show when microphone is inactive
        echo "0:::"
    fi
}

# =============================================================================
# Main Plugin Entry Points
# =============================================================================

load_plugin() {
    local status_result usage_status mute_status
    status_result=$(get_cached_or_fetch)
    usage_status="${status_result%:*}"
    mute_status="${status_result#*:}"
    
    # Show different text based on microphone state
    if [[ "$usage_status" == "active" ]]; then
        if [[ "$mute_status" == "muted" ]]; then
            printf 'MUTED'
        else
            printf 'ON'
        fi
    fi
    # When inactive, return nothing (plugin not shown)
}

# Only run if executed directly (not sourced)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    load_plugin
fi