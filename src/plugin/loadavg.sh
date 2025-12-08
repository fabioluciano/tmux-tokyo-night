#!/usr/bin/env bash
# Plugin: loadavg - System load average display

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$ROOT_DIR/../plugin_bootstrap.sh"

plugin_init "loadavg"

plugin_get_type() { printf 'static'; }

format_loadavg() {
    local one="$1" five="$2" fifteen="$3"
    local format
    format=$(get_cached_option "@powerkit_plugin_loadavg_format" "$POWERKIT_PLUGIN_LOADAVG_FORMAT")
    
    case "$format" in
        "1")  printf '%s' "$one" ;;
        "5")  printf '%s' "$five" ;;
        "15") printf '%s' "$fifteen" ;;
        *)    printf '%s %s %s' "$one" "$five" "$fifteen" ;;
    esac
}

get_loadavg_linux() {
    if [[ -r /proc/loadavg ]]; then
        read -r one five fifteen _ < /proc/loadavg
    else
        local uptime_out
        uptime_out=$(uptime 2>/dev/null)
        one=$(echo "$uptime_out" | grep -oE '[0-9]+\.[0-9]+' | sed -n '1p')
        five=$(echo "$uptime_out" | grep -oE '[0-9]+\.[0-9]+' | sed -n '2p')
        fifteen=$(echo "$uptime_out" | grep -oE '[0-9]+\.[0-9]+' | sed -n '3p')
    fi
    format_loadavg "$one" "$five" "$fifteen"
}

get_loadavg_macos() {
    local sysctl_out one five fifteen
    sysctl_out=$(sysctl -n vm.loadavg 2>/dev/null)
    
    if [[ -n "$sysctl_out" ]]; then
        one=$(echo "$sysctl_out" | awk '{print $2}')
        five=$(echo "$sysctl_out" | awk '{print $3}')
        fifteen=$(echo "$sysctl_out" | awk '{print $4}')
    else
        local uptime_out
        uptime_out=$(uptime 2>/dev/null)
        one=$(echo "$uptime_out" | grep -oE '[0-9]+\.[0-9]+' | sed -n '1p')
        five=$(echo "$uptime_out" | grep -oE '[0-9]+\.[0-9]+' | sed -n '2p')
        fifteen=$(echo "$uptime_out" | grep -oE '[0-9]+\.[0-9]+' | sed -n '3p')
    fi
    format_loadavg "$one" "$five" "$fifteen"
}

plugin_get_display_info() {
    local content="${1:-}"
    local show="1" accent="" accent_icon="" icon=""
    
    local num_cores
    num_cores=$(nproc 2>/dev/null || sysctl -n hw.ncpu 2>/dev/null || echo 4)
    
    local value
    value=$(echo "$content" | grep -oE '[0-9]+\.?[0-9]*' | head -1)
    local value_int
    value_int=$(awk "BEGIN {printf \"%d\", ${value:-0} * 100}" 2>/dev/null || echo 0)
    
    local display_condition display_threshold
    display_condition=$(get_cached_option "@powerkit_plugin_loadavg_display_condition" "always")
    display_threshold=$(get_cached_option "@powerkit_plugin_loadavg_display_threshold" "")
    
    if [[ "$display_condition" != "always" ]] && [[ -n "$display_threshold" ]]; then
        local threshold_int
        threshold_int=$(awk "BEGIN {printf \"%d\", $display_threshold * 100}" 2>/dev/null || echo 0)
        if ! evaluate_condition "$value_int" "$display_condition" "$threshold_int"; then
            show="0"
        fi
    fi
    
    local warning_mult critical_mult
    warning_mult=$(get_cached_option "@powerkit_plugin_loadavg_warning_threshold_multiplier" "$POWERKIT_PLUGIN_LOADAVG_WARNING_THRESHOLD_MULTIPLIER")
    critical_mult=$(get_cached_option "@powerkit_plugin_loadavg_critical_threshold_multiplier" "$POWERKIT_PLUGIN_LOADAVG_CRITICAL_THRESHOLD_MULTIPLIER")
    
    local warning_threshold critical_threshold
    warning_threshold=$(get_cached_option "@powerkit_plugin_loadavg_warning_threshold" "$((num_cores * warning_mult))")
    critical_threshold=$(get_cached_option "@powerkit_plugin_loadavg_critical_threshold" "$((num_cores * critical_mult))")
    
    local warning_int critical_int
    warning_int=$(awk "BEGIN {printf \"%d\", $warning_threshold * 100}" 2>/dev/null || echo 0)
    critical_int=$(awk "BEGIN {printf \"%d\", $critical_threshold * 100}" 2>/dev/null || echo 0)
    
    if [[ "$value_int" -ge "$critical_int" ]]; then
        accent=$(get_cached_option "@powerkit_plugin_loadavg_critical_accent_color" "$POWERKIT_PLUGIN_LOADAVG_CRITICAL_ACCENT_COLOR")
        accent_icon=$(get_cached_option "@powerkit_plugin_loadavg_critical_accent_color_icon" "$POWERKIT_PLUGIN_LOADAVG_CRITICAL_ACCENT_COLOR_ICON")
    elif [[ "$value_int" -ge "$warning_int" ]]; then
        accent=$(get_cached_option "@powerkit_plugin_loadavg_warning_accent_color" "$POWERKIT_PLUGIN_LOADAVG_WARNING_ACCENT_COLOR")
        accent_icon=$(get_cached_option "@powerkit_plugin_loadavg_warning_accent_color_icon" "$POWERKIT_PLUGIN_LOADAVG_WARNING_ACCENT_COLOR_ICON")
    fi
    
    build_display_info "$show" "$accent" "$accent_icon" "$icon"
}

load_plugin() {
    local cached_value
    if cached_value=$(cache_get "$CACHE_KEY" "$CACHE_TTL"); then
        printf '%s' "$cached_value"
        return
    fi

    local result
    if is_linux; then
        result=$(get_loadavg_linux)
    elif is_macos; then
        result=$(get_loadavg_macos)
    else
        result="N/A"
    fi

    cache_set "$CACHE_KEY" "$result"
    printf '%s' "$result"
}

[[ "${BASH_SOURCE[0]}" == "${0}" ]] && load_plugin || true
