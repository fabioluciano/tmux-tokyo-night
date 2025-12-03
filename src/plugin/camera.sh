#!/usr/bin/env bash
# =============================================================================
# Plugin: camera
# Description: Display camera status (active/inactive)
# Dependencies: Cross-platform (macOS system processes, Linux v4l2/lsof)
# =============================================================================
#
# Configuration options:
#   @theme_plugin_camera_icon               - Camera icon (default: 📷)
#   @theme_plugin_camera_icon_active        - Active camera icon (default: 🔴)
#   @theme_plugin_camera_accent_color       - Default accent color
#   @theme_plugin_camera_accent_color_icon  - Default icon accent color
#   @theme_plugin_camera_cache_ttl          - Cache time in seconds (default: 3)
#   @theme_plugin_camera_show_when_inactive - Show when camera is off: true|false (default: false)
#
# Example configurations:
#   # Show even when camera is inactive
#   set -g @theme_plugin_camera_show_when_inactive "true"
#   
#   # Custom icons
#   set -g @theme_plugin_camera_icon "📸"
#   set -g @theme_plugin_camera_icon_active "🟢"
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

# Get plugin options with defaults
get_plugin_option() {
    local option="$1"
    local default="$2"
    get_tmux_option "@theme_plugin_camera_$option" "$default"
}

# Plugin variables for theme system
# shellcheck disable=SC2034
plugin_camera_icon=$(get_plugin_option "icon" "$THEME_DEFAULT_PLUGIN_CAMERA_ICON")
# shellcheck disable=SC2034
plugin_camera_accent_color=$(get_plugin_option "accent_color" "$PLUGIN_CAMERA_ACCENT_COLOR")
# shellcheck disable=SC2034
plugin_camera_accent_color_icon=$(get_plugin_option "accent_color_icon" "$PLUGIN_CAMERA_ACCENT_COLOR_ICON")

export plugin_camera_icon plugin_camera_accent_color plugin_camera_accent_color_icon

# =============================================================================
# Plugin Interface Implementation
# =============================================================================

# Function to inform the plugin type to the renderer
plugin_get_type() {
    printf 'static'
}

# Plugin settings
PLUGIN_ICON=$(get_plugin_option "icon" "$THEME_DEFAULT_PLUGIN_CAMERA_ICON")
PLUGIN_ACCENT_COLOR=$(get_plugin_option "accent_color" "${PLUGIN_CAMERA_ACCENT_COLOR:-blue7}")
PLUGIN_ACCENT_COLOR_ICON=$(get_plugin_option "accent_color_icon" "${PLUGIN_CAMERA_ACCENT_COLOR_ICON:-blue0}")
PLUGIN_ACTIVE_ACCENT_COLOR=$(get_plugin_option "active_accent_color" "${PLUGIN_CAMERA_ACTIVE_ACCENT_COLOR:-red}")
PLUGIN_ACTIVE_ACCENT_COLOR_ICON=$(get_plugin_option "active_accent_color_icon" "${PLUGIN_CAMERA_ACTIVE_ACCENT_COLOR_ICON:-red1}")
PLUGIN_CACHE_TTL=$(get_plugin_option "cache_ttl" "$THEME_DEFAULT_PLUGIN_CAMERA_CACHE_TTL")
PLUGIN_SHOW_WHEN_INACTIVE=$(get_plugin_option "show_when_inactive" "$THEME_DEFAULT_PLUGIN_CAMERA_SHOW_WHEN_INACTIVE")

# =============================================================================
# Camera Detection - macOS
# =============================================================================

detect_camera_usage_macos() {
    # Method 1: Check for VDCAssistant process (most reliable and fastest)
    if pgrep -q "VDCAssistant" 2>/dev/null; then
        echo "active"
        return
    fi
    
    # Method 2: Check camera daemon for CPU activity (single check, no delays)
    local camera_pid
    camera_pid=$(pgrep -f "appleh16camerad" 2>/dev/null)
    if [[ -n "$camera_pid" ]]; then
        local cpu_usage
        cpu_usage=$(ps -p "$camera_pid" -o %cpu= 2>/dev/null | tr -d ' ' | cut -d. -f1)
        if [[ -n "$cpu_usage" && "$cpu_usage" -ge 3 ]]; then
            echo "active"
            return
        fi
    fi
    
    # Method 3: Check cameracaptured for high CPU
    local capture_pid
    capture_pid=$(pgrep -f "cameracaptured" 2>/dev/null)
    if [[ -n "$capture_pid" ]]; then
        local cpu_usage
        cpu_usage=$(ps -p "$capture_pid" -o %cpu= 2>/dev/null | tr -d ' ' | cut -d. -f1)
        if [[ -n "$cpu_usage" && "$cpu_usage" -ge 3 ]]; then
            echo "active"
            return
        fi
    fi
    
    echo "inactive"
}

# =============================================================================
# Camera Detection - Linux
# =============================================================================

detect_camera_usage_linux() {
    # Method 1: Check if any video devices are being accessed
    if lsof /dev/video* 2>/dev/null | grep -q "/dev/video"; then
        echo "active"
        return
    fi
    
    # Method 2: Check for processes using video4linux devices
    if fuser /dev/video* 2>/dev/null | grep -q "[0-9]"; then
        echo "active"
        return
    fi
    
    # Method 3: Check common camera applications with significant CPU usage
    local camera_processes=("gstreamer" "ffmpeg" "vlc" "cheese" "guvcview" "kamoso" "obs" "zoom" "teams" "skype" "discord")
    for proc in "${camera_processes[@]}"; do
        local proc_pids
        proc_pids=$(pgrep -f "$proc" 2>/dev/null)
        if [[ -n "$proc_pids" ]]; then
            for pid in $proc_pids; do
                local cpu_usage
                cpu_usage=$(ps -p "$pid" -o %cpu= 2>/dev/null | tr -d ' ' | cut -d. -f1)
                if [[ -n "$cpu_usage" && "$cpu_usage" -ge 2 ]]; then
                    echo "active"
                    return
                fi
            done
        fi
    done
    
    # Method 4: Check for v4l2 processes (Video4Linux2)
    if pgrep -f "v4l2" >/dev/null 2>&1; then
        echo "active"
        return
    fi
    
    # Method 5: Check systemd/journal logs for camera usage (if available)
    if command -v journalctl >/dev/null 2>&1; then
        if journalctl --since="10 seconds ago" 2>/dev/null | \
           grep -i -E "(camera|video.*device|v4l2)" | \
           grep -E "(start|open|active)" >/dev/null 2>&1; then
            echo "active"
            return
        fi
    fi
    
    # Method 6: Check /proc/*/fd for video device file descriptors
    if find /proc/[0-9]*/fd -type l -exec ls -l {} + 2>/dev/null | \
       grep -q "/dev/video" 2>/dev/null; then
        echo "active"
        return
    fi
    
    echo "inactive"
}

# =============================================================================
# Camera Detection - Cross-Platform Entry Point
# =============================================================================

detect_camera_usage() {
    if [[ "$OSTYPE" == "darwin"* ]]; then
        detect_camera_usage_macos
    elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
        detect_camera_usage_linux
    else
        echo "inactive"
    fi
}

# =============================================================================
# Cache Management
# =============================================================================

get_cache_file() {
    echo "/tmp/tmux_camera_status_$$"
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
        result=$(detect_camera_usage)
        echo "$result" > "$cache_file"
        echo "$result"
    fi
}

# =============================================================================
# Plugin Display
# =============================================================================

show_camera_plugin() {
    local camera_status
    camera_status=$(get_cached_or_fetch)
    
    # Choose icon and color based on status
    local icon color_icon color_text
    if [[ "$camera_status" == "active" ]]; then
        icon="$PLUGIN_ICON_ACTIVE"
        color_icon="red1"  # Red for active camera
        color_text="red"
    else
        # Don't show if inactive and show_when_inactive is false
        [[ "$PLUGIN_SHOW_WHEN_INACTIVE" == "false" ]] && return
        
        icon="$PLUGIN_ICON"
        color_icon="$PLUGIN_ACCENT_COLOR_ICON"
        color_text="$PLUGIN_ACCENT_COLOR"
    fi
    
    # Build display string
    echo "#[fg=$color_icon]${icon} #[fg=$color_text]Camera"
}

# =============================================================================
# Plugin Display Info for Render System
# =============================================================================

# This function is called by render_plugins.sh to get display decisions
# Output format: "show:accent:accent_icon:icon"
plugin_get_display_info() {
    local _content="$1"
    
    local camera_status
    camera_status=$(get_cached_or_fetch)
    
    # Only show when camera is active
    if [[ "$camera_status" == "active" ]]; then
        # Customizable colors when camera is active - no icon, just text
        echo "1:$PLUGIN_ACTIVE_ACCENT_COLOR:$PLUGIN_ACTIVE_ACCENT_COLOR_ICON:"
    else
        # Don't show when camera is inactive
        echo "0:::"
    fi
}

# =============================================================================
# Main Plugin Entry Points
# =============================================================================

# =============================================================================
# Plugin Entry Point
# =============================================================================

load_plugin() {
    local camera_status
    camera_status=$(get_cached_or_fetch)
    
    # Don't show if inactive and show_when_inactive is false
    if [[ "$camera_status" == "inactive" && "$PLUGIN_SHOW_WHEN_INACTIVE" == "false" ]]; then
        return
    fi
    
    # Return text only when camera is active
    if [[ "$camera_status" == "active" ]]; then
        printf 'ON'
    fi
    # When inactive, return nothing (plugin not shown)
}

# Only run if executed directly (not sourced)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    load_plugin
fi