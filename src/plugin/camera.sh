#!/usr/bin/env bash
# Plugin: camera - Display camera status (macOS/Linux)

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$ROOT_DIR/../plugin_bootstrap.sh"

plugin_init "camera"

# Configuration
_icon=$(get_tmux_option "@powerkit_plugin_camera_icon" "$POWERKIT_PLUGIN_CAMERA_ICON")
_active_accent=$(get_tmux_option "@powerkit_plugin_camera_active_accent_color" "$POWERKIT_PLUGIN_CAMERA_ACTIVE_ACCENT_COLOR")
_active_accent_icon=$(get_tmux_option "@powerkit_plugin_camera_active_accent_color_icon" "$POWERKIT_PLUGIN_CAMERA_ACTIVE_ACCENT_COLOR_ICON")

# Check CPU usage of process
check_cpu() {
    local pid="$1" min="${2:-1}"
    local cpu=$(ps -p "$pid" -o %cpu= 2>/dev/null | tr -d ' ' | cut -d. -f1)
    [[ -n "$cpu" && "$cpu" -ge "$min" ]]
}

# macOS detection
detect_macos() {
    local procs=("VDCAssistant" "appleh16camerad" "cameracaptured")
    for p in "${procs[@]}"; do
        local pid=$(pgrep -f "$p" 2>/dev/null)
        [[ -n "$pid" ]] && check_cpu "$pid" 1 && { echo "active"; return; }
    done
    echo "inactive"
}

# Linux detection
detect_linux() {
    # Check video devices
    lsof /dev/video* 2>/dev/null | grep -q "/dev/video" && { echo "active"; return; }
    fuser /dev/video* 2>/dev/null | grep -q "[0-9]" && { echo "active"; return; }

    # Check camera apps
    local apps=("gstreamer" "ffmpeg" "vlc" "cheese" "guvcview" "kamoso" "obs" "zoom" "teams" "skype" "discord")
    for app in "${apps[@]}"; do
        for pid in $(pgrep -f "$app" 2>/dev/null); do
            check_cpu "$pid" 2 && { echo "active"; return; }
        done
    done

    # Check v4l2
    pgrep -f "v4l2" &>/dev/null && { echo "active"; return; }

    # Check /proc for video fd
    find /proc/[0-9]*/fd -type l -exec ls -l {} + 2>/dev/null | grep -q "/dev/video" && { echo "active"; return; }

    echo "inactive"
}

detect_camera() {
    is_macos && detect_macos || detect_linux
}

get_status() {
    local cached
    if cached=$(cache_get "$CACHE_KEY" "$CACHE_TTL"); then
        echo "$cached"
    else
        local r=$(detect_camera)
        cache_set "$CACHE_KEY" "$r"
        echo "$r"
    fi
}

plugin_get_type() { printf 'conditional'; }

plugin_get_display_info() {
    local status=$(get_status)
    [[ "$status" == "active" ]] && echo "1:$_active_accent:$_active_accent_icon:$_icon" || echo "0:::"
}

load_plugin() {
    local status=$(get_status)
    [[ "$status" == "active" ]] && printf 'ON'
}

[[ "${BASH_SOURCE[0]}" == "${0}" ]] && load_plugin || true
