#!/usr/bin/env bash
# =============================================================================
# Plugin: fan
# Description: Display fan speed (RPM) for system cooling fans
# Dependencies: None (uses sysfs on Linux, smctemp on macOS)
# =============================================================================

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$ROOT_DIR/../plugin_bootstrap.sh"

plugin_init "fan"

# =============================================================================
# Fan Speed Functions
# =============================================================================

get_fan_hwmon() {
    # Linux: Read from hwmon subsystem
    for dir in /sys/class/hwmon/hwmon*; do
        [[ -d "$dir" ]] || continue
        
        # Look for fan speed inputs
        for fan_file in "$dir"/fan*_input; do
            [[ -f "$fan_file" ]] || continue
            local rpm
            rpm=$(<"$fan_file")
            [[ -n "$rpm" && "$rpm" -gt 0 ]] && { echo "$rpm"; return 0; }
        done
    done
    return 1
}

get_fan_dell() {
    # Dell-specific: dell_smm driver
    local dir
    for dir in /sys/class/hwmon/hwmon*; do
        [[ -f "$dir/name" && "$(<"$dir/name")" == "dell_smm" ]] || continue
        for fan in "$dir"/fan*_input; do
            [[ -f "$fan" ]] || continue
            local rpm=$(<"$fan")
            [[ -n "$rpm" && "$rpm" -gt 0 ]] && { echo "$rpm"; return 0; }
        done
    done
    return 1
}

get_fan_thinkpad() {
    # ThinkPad: thinkpad_acpi
    local fan_file="/proc/acpi/ibm/fan"
    [[ -f "$fan_file" ]] || return 1
    local rpm
    rpm=$(awk '/^speed:/ {print $2}' "$fan_file" 2>/dev/null)
    [[ -n "$rpm" && "$rpm" -gt 0 ]] && { echo "$rpm"; return 0; }
    return 1
}

get_fan_macos() {
    # macOS: Try different methods
    # Note: MacBook Air (M1/M2/M3/M4) are fanless - this plugin won't work on them
    
    # Method 1: osx-cpu-temp (most common)
    if command -v osx-cpu-temp &>/dev/null; then
        local output rpm
        output=$(osx-cpu-temp -f 2>/dev/null)
        # Check if there are fans (Num fans: 0 means fanless)
        if ! echo "$output" | grep -q "Num fans: 0"; then
            rpm=$(echo "$output" | grep -oE 'Fan [0-9]+.*?([0-9]+) RPM' | grep -oE '[0-9]+ RPM' | head -1 | grep -oE '[0-9]+')
            [[ -n "$rpm" && "$rpm" -gt 0 ]] && { echo "$rpm"; return 0; }
        fi
    fi
    
    # Method 2: smctemp (if installed)
    if command -v smctemp &>/dev/null; then
        local rpm
        rpm=$(smctemp -f 2>/dev/null | grep -oE '[0-9]+' | head -1)
        [[ -n "$rpm" && "$rpm" -gt 0 ]] && { echo "$rpm"; return 0; }
    fi
    
    # Method 3: iStats (Ruby gem)
    if command -v istats &>/dev/null; then
        local rpm
        rpm=$(istats fan speed 2>/dev/null | grep -oE '[0-9]+' | head -1)
        [[ -n "$rpm" && "$rpm" -gt 0 ]] && { echo "$rpm"; return 0; }
    fi
    
    return 1
}

get_fan_speed() {
    local source
    source=$(get_cached_option "@powerkit_plugin_fan_source" "$POWERKIT_PLUGIN_FAN_SOURCE")
    
    local rpm=""
    
    case "$source" in
        dell)     rpm=$(get_fan_dell) ;;
        thinkpad) rpm=$(get_fan_thinkpad) ;;
        hwmon)    rpm=$(get_fan_hwmon) ;;
        auto|*)
            if is_macos; then
                rpm=$(get_fan_macos)
            else
                rpm=$(get_fan_dell) || \
                rpm=$(get_fan_thinkpad) || \
                rpm=$(get_fan_hwmon)
            fi
            ;;
    esac
    
    [[ -n "$rpm" ]] && printf '%s' "$rpm"
}

format_rpm() {
    local rpm="$1"
    local format
    format=$(get_cached_option "@powerkit_plugin_fan_format" "$POWERKIT_PLUGIN_FAN_FORMAT")
    
    case "$format" in
        krpm)
            # Display as X.Xk
            awk "BEGIN {printf \"%.1fk\", $rpm / 1000}"
            ;;
        full)
            # Full RPM with suffix
            echo "${rpm} RPM"
            ;;
        raw|*)
            # Just the number
            echo "$rpm"
            ;;
    esac
}

# =============================================================================
# Plugin Interface
# =============================================================================

plugin_get_type() { printf 'conditional'; }

plugin_get_display_info() {
    local content="${1:-}"
    local show="1" accent="" accent_icon="" icon=""
    
    [[ -z "$content" ]] && { build_display_info "0" "" "" ""; return; }
    
    local value warning_threshold critical_threshold
    value=$(echo "$content" | grep -oE '[0-9]+' | head -1)
    [[ -z "$value" ]] && { build_display_info "0" "" "" ""; return; }
    
    warning_threshold=$(get_cached_option "@powerkit_plugin_fan_warning_threshold" "$POWERKIT_PLUGIN_FAN_WARNING_THRESHOLD")
    critical_threshold=$(get_cached_option "@powerkit_plugin_fan_critical_threshold" "$POWERKIT_PLUGIN_FAN_CRITICAL_THRESHOLD")
    
    if [[ "$value" -ge "$critical_threshold" ]]; then
        accent=$(get_cached_option "@powerkit_plugin_fan_critical_accent_color" "$POWERKIT_PLUGIN_FAN_CRITICAL_ACCENT_COLOR")
        accent_icon=$(get_cached_option "@powerkit_plugin_fan_critical_accent_color_icon" "$POWERKIT_PLUGIN_FAN_CRITICAL_ACCENT_COLOR_ICON")
        icon=$(get_cached_option "@powerkit_plugin_fan_icon_fast" "$POWERKIT_PLUGIN_FAN_ICON_FAST")
    elif [[ "$value" -ge "$warning_threshold" ]]; then
        accent=$(get_cached_option "@powerkit_plugin_fan_warning_accent_color" "$POWERKIT_PLUGIN_FAN_WARNING_ACCENT_COLOR")
        accent_icon=$(get_cached_option "@powerkit_plugin_fan_warning_accent_color_icon" "$POWERKIT_PLUGIN_FAN_WARNING_ACCENT_COLOR_ICON")
    fi
    
    build_display_info "$show" "$accent" "$accent_icon" "$icon"
}

# =============================================================================
# Main
# =============================================================================

load_plugin() {
    # Check if we should hide when idle
    local hide_when_idle
    hide_when_idle=$(get_cached_option "@powerkit_plugin_fan_hide_when_idle" "$POWERKIT_PLUGIN_FAN_HIDE_WHEN_IDLE")
    
    local cached
    if cached=$(cache_get "$CACHE_KEY" "$CACHE_TTL"); then
        printf '%s' "$cached"
        return 0
    fi
    
    local rpm
    rpm=$(get_fan_speed) || return 0
    [[ -z "$rpm" ]] && return 0
    
    # Hide if RPM is 0 and hide_when_idle is true
    if [[ "$hide_when_idle" == "true" && "$rpm" -eq 0 ]]; then
        return 0
    fi
    
    local result
    result=$(format_rpm "$rpm")
    
    cache_set "$CACHE_KEY" "$result"
    printf '%s' "$result"
}

[[ "${BASH_SOURCE[0]}" == "${0}" ]] && load_plugin || true
