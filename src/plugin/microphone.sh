#!/usr/bin/env bash
# =============================================================================
# Plugin: microphone
# Description: Display microphone activity status (active/inactive)
# Dependencies: Cross-platform (macOS system processes, Linux ALSA/PulseAudio)
# =============================================================================
#
# Configuration options:
#   @theme_plugin_microphone_icon                 - Microphone icon (default: )
#   @theme_plugin_microphone_accent_color         - Default accent color
#   @theme_plugin_microphone_accent_color_icon    - Default icon accent color  
#   @theme_plugin_microphone_active_accent_color  - Active accent color (default: red)
#   @theme_plugin_microphone_active_accent_color_icon - Active icon accent color (default: red1)
#   @theme_plugin_microphone_cache_ttl            - Cache time in seconds (default: 1)
#   @theme_plugin_microphone_show_when_inactive   - Show when microphone is off (default: false)
#
# Example configurations:
#   # Show microphone status even when inactive
#   set -g @theme_plugin_microphone_show_when_inactive "true"
#   
#   # Custom colors for active microphone
#   set -g @theme_plugin_microphone_active_accent_color "orange"
#   set -g @theme_plugin_microphone_active_accent_color_icon "yellow"
#   
#   # Custom cache time
#   set -g @theme_plugin_microphone_cache_ttl "2"
#
# =============================================================================

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck source=src/defaults.sh
. "$ROOT_DIR/../defaults.sh"
# shellcheck source=src/utils.sh
. "$ROOT_DIR/../utils.sh"

# =============================================================================
# Plugin Configuration
# =============================================================================

# Plugin variables for theme system (exported from defaults.sh)
export plugin_microphone_icon plugin_microphone_accent_color plugin_microphone_accent_color_icon

# =============================================================================
# Plugin Interface Implementation
# =============================================================================

# Function to inform the plugin type to the renderer
plugin_get_type() {
    printf 'conditional'
}

# Plugin settings
PLUGIN_ICON="$PLUGIN_MICROPHONE_ICON"
PLUGIN_ACCENT_COLOR="$PLUGIN_MICROPHONE_ACCENT_COLOR"
PLUGIN_ACCENT_COLOR_ICON="$PLUGIN_MICROPHONE_ACCENT_COLOR_ICON"
PLUGIN_ACTIVE_ACCENT_COLOR="$PLUGIN_MICROPHONE_ACTIVE_ACCENT_COLOR"
PLUGIN_ACTIVE_ACCENT_COLOR_ICON="$PLUGIN_MICROPHONE_ACTIVE_ACCENT_COLOR_ICON"
PLUGIN_CACHE_TTL="$PLUGIN_MICROPHONE_CACHE_TTL"
PLUGIN_SHOW_WHEN_INACTIVE="$PLUGIN_MICROPHONE_SHOW_WHEN_INACTIVE"

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

detect_microphone_usage_linux() {
    # Method 1: Check PulseAudio/ALSA for active recording
    if command -v pactl >/dev/null 2>&1; then
        if pactl list short source-outputs 2>/dev/null | grep -q .; then
            echo "active"
            return
        fi
    fi
    
    # Method 2: Check ALSA capture devices
    if command -v arecord >/dev/null 2>&1; then
        if lsof /dev/snd/* 2>/dev/null | grep -q "^[^[:space:]]*[[:space:]]*[0-9]*[[:space:]]*[^[:space:]]*[[:space:]]*[0-9]*w"; then
            echo "active"
            return
        fi
    fi
    
    # Method 3: Check common microphone applications
    local mic_processes=("zoom" "teams" "discord" "skype" "obs" "audacity" "pavucontrol" "pulseaudio")
    for proc in "${mic_processes[@]}"; do
        if pgrep -qi "$proc" >/dev/null 2>&1; then
            echo "active"
            return
        fi
    done
    
    echo "inactive"
}

# =============================================================================
# Microphone Detection - Cross-Platform Entry Point
# =============================================================================

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
        local result
        result=$(detect_microphone_usage)
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
    
    local microphone_status
    microphone_status=$(get_cached_or_fetch)
    
    # Only show when microphone is active
    if [[ "$microphone_status" == "active" ]]; then
        # Active colors - red background, no icon
        echo "1:$PLUGIN_ACTIVE_ACCENT_COLOR:$PLUGIN_ACTIVE_ACCENT_COLOR_ICON:"
    else
        # Don't show when microphone is inactive
        echo "0:::"
    fi
}

# =============================================================================
# Main Plugin Entry Points
# =============================================================================

load_plugin() {
    local microphone_status
    microphone_status=$(get_cached_or_fetch)
    
    # Only show when microphone is active
    if [[ "$microphone_status" == "active" ]]; then
        printf 'ON'
    fi
    # When inactive, return nothing (plugin not shown)
}

# Only run if executed directly (not sourced)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    load_plugin
fi