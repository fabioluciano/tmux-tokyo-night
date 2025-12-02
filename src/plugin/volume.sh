#!/usr/bin/env bash
# =============================================================================
# Plugin: volume
# Description: Display system volume percentage with mute indicator
# Dependencies: pactl/pamixer (Linux), osascript (macOS)
# =============================================================================
#
# Configuration options:
#   @theme_plugin_volume_icon              - Default icon (default: 󰕾)
#   @theme_plugin_volume_icon_muted        - Icon when muted (default: 󰖁)
#   @theme_plugin_volume_icon_low          - Icon for low volume (default: 󰕿)
#   @theme_plugin_volume_icon_medium       - Icon for medium volume (default: 󰖀)
#   @theme_plugin_volume_accent_color      - Default accent color
#   @theme_plugin_volume_accent_color_icon - Default icon accent color
#   @theme_plugin_volume_cache_ttl         - Cache time in seconds (default: 2)
#
# Threshold options:
#   @theme_plugin_volume_low_threshold     - Below this = low icon (default: 30)
#   @theme_plugin_volume_medium_threshold  - Below this = medium icon (default: 70)
#   @theme_plugin_volume_muted_accent_color      - Color when muted
#   @theme_plugin_volume_muted_accent_color_icon - Icon color when muted
#
# Example configurations:
#   # Custom icons
#   set -g @theme_plugin_volume_icon "🔊"
#   set -g @theme_plugin_volume_icon_muted "🔇"
#
#   # Change thresholds
#   set -g @theme_plugin_volume_low_threshold "20"
#   set -g @theme_plugin_volume_medium_threshold "60"
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
plugin_volume_icon=$(get_tmux_option "@theme_plugin_volume_icon" "${PLUGIN_VOLUME_ICON:-󰕾}")
# shellcheck disable=SC2034
plugin_volume_accent_color=$(get_tmux_option "@theme_plugin_volume_accent_color" "${PLUGIN_VOLUME_ACCENT_COLOR:-blue7}")
# shellcheck disable=SC2034
plugin_volume_accent_color_icon=$(get_tmux_option "@theme_plugin_volume_accent_color_icon" "${PLUGIN_VOLUME_ACCENT_COLOR_ICON:-blue0}")

# Cache TTL in seconds (default: 2 seconds - volume changes frequently)
VOLUME_CACHE_TTL=$(get_tmux_option "@theme_plugin_volume_cache_ttl" "${PLUGIN_VOLUME_CACHE_TTL:-2}")
VOLUME_CACHE_KEY="volume"

export plugin_volume_icon plugin_volume_accent_color plugin_volume_accent_color_icon

# =============================================================================
# Platform Detection
# =============================================================================

command_exists() {
    command -v "$1" &>/dev/null
}

# =============================================================================
# Volume Detection Functions
# =============================================================================

# Get volume on macOS using osascript
get_volume_macos() {
    osascript -e 'output volume of (get volume settings)' 2>/dev/null
}

# Check if muted on macOS
is_muted_macos() {
    local muted
    muted=$(osascript -e 'output muted of (get volume settings)' 2>/dev/null)
    [[ "$muted" == "true" ]]
}

# Get volume on Linux using pactl (PulseAudio/PipeWire)
get_volume_pactl() {
    # Get the default sink volume
    pactl get-sink-volume @DEFAULT_SINK@ 2>/dev/null | \
        grep -oP '\d+%' | head -1 | tr -d '%'
}

# Check if muted using pactl
is_muted_pactl() {
    local muted
    muted=$(pactl get-sink-mute @DEFAULT_SINK@ 2>/dev/null | grep -oP 'yes|no')
    [[ "$muted" == "yes" ]]
}

# Get volume using pamixer (alternative for Linux)
get_volume_pamixer() {
    pamixer --get-volume 2>/dev/null
}

# Check if muted using pamixer
is_muted_pamixer() {
    pamixer --get-mute 2>/dev/null | grep -q "true"
}

# Get volume using amixer (ALSA - fallback)
get_volume_amixer() {
    amixer sget Master 2>/dev/null | \
        grep -oP '\[\d+%\]' | head -1 | tr -d '[]%'
}

# Check if muted using amixer
is_muted_amixer() {
    amixer sget Master 2>/dev/null | grep -q '\[off\]'
}

# Get volume using wpctl (WirePlumber/PipeWire)
get_volume_wpctl() {
    local vol
    vol=$(wpctl get-volume @DEFAULT_AUDIO_SINK@ 2>/dev/null | awk '{print $2}')
    if [[ -n "$vol" ]]; then
        # Convert from decimal (0.75) to percentage (75)
        awk "BEGIN {printf \"%.0f\", $vol * 100}"
    fi
}

# Check if muted using wpctl
is_muted_wpctl() {
    wpctl get-volume @DEFAULT_AUDIO_SINK@ 2>/dev/null | grep -q '\[MUTED\]'
}

# =============================================================================
# Main Volume Functions
# =============================================================================

volume_get_percentage() {
    local percentage=""
    
    if is_macos; then
        percentage=$(get_volume_macos)
    elif command_exists "wpctl"; then
        percentage=$(get_volume_wpctl)
    elif command_exists "pactl"; then
        percentage=$(get_volume_pactl)
    elif command_exists "pamixer"; then
        percentage=$(get_volume_pamixer)
    elif command_exists "amixer"; then
        percentage=$(get_volume_amixer)
    fi
    
    # Ensure we return a valid number
    if [[ -n "$percentage" && "$percentage" =~ ^[0-9]+$ ]]; then
        printf '%s' "$percentage"
    fi
}

volume_is_muted() {
    if is_macos; then
        is_muted_macos && return 0
    elif command_exists "wpctl"; then
        is_muted_wpctl && return 0
    elif command_exists "pactl"; then
        is_muted_pactl && return 0
    elif command_exists "pamixer"; then
        is_muted_pamixer && return 0
    elif command_exists "amixer"; then
        is_muted_amixer && return 0
    fi
    return 1
}

volume_is_available() {
    local percentage
    percentage=$(volume_get_percentage)
    [[ -n "$percentage" ]]
}

# =============================================================================
# Plugin Interface Implementation
# =============================================================================

# Function to inform the plugin type to the renderer
plugin_get_type() {
    printf 'static'
}

# This function is called by render_plugins.sh to get display decisions
# Output format: "show:accent:accent_icon:icon"
plugin_get_display_info() {
    local content="$1"
    local show="1"
    local accent=""
    local accent_icon=""
    local icon=""
    
    # Extract numeric value from content (handles "MUTED" case)
    local value
    value=$(extract_numeric "$content")
    
    # Check if muted
    # Use get_cached_option for performance in render loop
    if [[ "$content" == "MUTED" ]] || volume_is_muted; then
        icon=$(get_cached_option "@theme_plugin_volume_icon_muted" "${PLUGIN_VOLUME_ICON_MUTED:-󰖁}")
        accent=$(get_cached_option "@theme_plugin_volume_muted_accent_color" "")
        accent_icon=$(get_cached_option "@theme_plugin_volume_muted_accent_color_icon" "")
    elif [[ -n "$value" ]]; then
        # Select icon based on volume level
        local low_threshold medium_threshold
        low_threshold=$(get_cached_option "@theme_plugin_volume_low_threshold" "${PLUGIN_VOLUME_LOW_THRESHOLD:-30}")
        medium_threshold=$(get_cached_option "@theme_plugin_volume_medium_threshold" "${PLUGIN_VOLUME_MEDIUM_THRESHOLD:-70}")
        
        if [[ "$value" -le "$low_threshold" ]]; then
            icon=$(get_cached_option "@theme_plugin_volume_icon_low" "${PLUGIN_VOLUME_ICON_LOW:-󰕿}")
        elif [[ "$value" -le "$medium_threshold" ]]; then
            icon=$(get_cached_option "@theme_plugin_volume_icon_medium" "${PLUGIN_VOLUME_ICON_MEDIUM:-󰖀}")
        else
            icon=$(get_cached_option "@theme_plugin_volume_icon" "${PLUGIN_VOLUME_ICON:-󰕾}")
        fi
    fi
    
    build_display_info "$show" "$accent" "$accent_icon" "$icon"
}

# =============================================================================
# Main Plugin Logic
# =============================================================================

load_plugin() {
    # Check cache first
    local cached_value
    if cached_value=$(cache_get "$VOLUME_CACHE_KEY" "$VOLUME_CACHE_TTL"); then
        printf '%s' "$cached_value"
        return 0
    fi

    # Check if volume control is available
    if ! volume_is_available; then
        return 0
    fi

    local result
    
    # Check mute status first
    if volume_is_muted; then
        result="MUTED"
    else
        local percentage
        percentage=$(volume_get_percentage)
        result="${percentage}%"
    fi

    # Cache and output
    cache_set "$VOLUME_CACHE_KEY" "$result"
    printf '%s' "$result"
}

# Only run if executed directly (not sourced)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    load_plugin
fi
