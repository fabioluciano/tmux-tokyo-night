#!/usr/bin/env bash
# Plugin: brightness - Display screen brightness level (Linux only)
# Methods: sysfs, brightnessctl, light, xbacklight

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$ROOT_DIR/../plugin_bootstrap.sh"

plugin_init "brightness"

# Get brightness (Linux only)
get_brightness() {
    is_linux || return 1

    # Method 1: sysfs
    local dir="/sys/class/backlight"
    if [[ -d "$dir" ]]; then
        for d in "$dir"/*; do
            [[ -f "$d/brightness" && -f "$d/max_brightness" ]] || continue
            awk 'FNR==1{c=$0} END{if(FNR==2 && $0>0) printf "%d", (c/$0)*100}' \
                "$d/brightness" "$d/max_brightness" 2>/dev/null && return 0
        done
    fi

    # Method 2: brightnessctl
    local max=$(brightnessctl max 2>/dev/null)
    [[ -n "$max" && "$max" -gt 0 ]] && { brightnessctl get 2>/dev/null | awk -v m="$max" '{printf "%d", ($0/m)*100}'; return 0; }

    # Method 3: light
    light -G 2>/dev/null | awk '{printf "%d", $1}' && return 0

    # Method 4: xbacklight
    xbacklight -get 2>/dev/null | awk '{printf "%d", $1}' && return 0

    return 1
}

has_brightness() {
    local b=$(get_brightness)
    [[ -n "$b" && "$b" =~ ^[0-9]+$ ]]
}

plugin_get_type() { printf 'conditional'; }

plugin_get_display_info() {
    local content="$1" show="1" accent="" accent_icon="" icon=""
    local value=$(extract_numeric "$content")

    # Display condition
    local cond=$(get_cached_option "@powerkit_plugin_brightness_display_condition" "always")
    local thresh=$(get_cached_option "@powerkit_plugin_brightness_display_threshold" "")
    [[ "$cond" != "always" && -n "$thresh" ]] && ! evaluate_condition "$value" "$cond" "$thresh" && show="0"

    # Dynamic icon
    if [[ -n "$value" ]]; then
        local low=$(get_cached_option "@powerkit_plugin_brightness_icon_low" "$POWERKIT_PLUGIN_BRIGHTNESS_ICON_LOW")
        local med=$(get_cached_option "@powerkit_plugin_brightness_icon_medium" "$POWERKIT_PLUGIN_BRIGHTNESS_ICON_MEDIUM")
        local high=$(get_cached_option "@powerkit_plugin_brightness_icon_high" "$POWERKIT_PLUGIN_BRIGHTNESS_ICON_HIGH")
        [[ "$value" -lt 30 ]] && icon="$low" || { [[ "$value" -lt 70 ]] && icon="$med" || icon="$high"; }
    fi

    build_display_info "$show" "$accent" "$accent_icon" "$icon"
}

load_plugin() {
    has_brightness || return 0

    local cached
    if cached=$(cache_get "$CACHE_KEY" "$CACHE_TTL"); then
        printf '%s' "$cached"
        return 0
    fi

    local b=$(get_brightness)
    [[ -z "$b" || ! "$b" =~ ^[0-9]+$ ]] && return 0

    local result="${b}%"
    cache_set "$CACHE_KEY" "$result"
    printf '%s' "$result"
}

[[ "${BASH_SOURCE[0]}" == "${0}" ]] && load_plugin || true
