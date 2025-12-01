#!/usr/bin/env bash
# =============================================================================
# Plugin: temperature
# Description: Display CPU/system temperature with dynamic threshold colors
# Dependencies: None (uses native OS commands or common tools)
# =============================================================================
#
# Configuration options:
#   @theme_plugin_temperature_icon                 - Default icon (default: 󰔏)
#   @theme_plugin_temperature_accent_color         - Default accent color
#   @theme_plugin_temperature_accent_color_icon    - Default icon accent color
#   @theme_plugin_temperature_unit                 - Unit: C or F (default: C)
#   @theme_plugin_temperature_source               - Source (default: cpu)
#       • cpu, coretemp    - CPU cores (Intel coretemp, AMD k10temp)
#       • cpu-pkg          - CPU package (x86_pkg_temp)
#       • cpu-acpi, tcpu   - CPU via ACPI (TCPU)
#       • nvme, ssd        - NVMe SSD
#       • wifi, wireless   - WiFi chip (iwlwifi)
#       • acpi, ambient    - System ambient/chassis temperature
#       • dell, dell_smm   - Dell system sensors
#       • auto             - Auto-detect (prefer CPU)
#   @theme_plugin_temperature_cache_ttl            - Cache time in seconds (default: 5)
#
# Threshold options:
#   @theme_plugin_temperature_warning_threshold    - Warning threshold (default: 60)
#   @theme_plugin_temperature_critical_threshold   - Critical threshold (default: 80)
#   @theme_plugin_temperature_warning_accent_color - Warning color
#   @theme_plugin_temperature_critical_accent_color - Critical color
#
# Platform support:
#   - macOS: Uses 'osx-cpu-temp' or 'powermetrics' (Apple Silicon)
#   - Linux: Uses '/sys/class/thermal/' or 'sensors' (lm-sensors)
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
plugin_temperature_icon=$(get_tmux_option "@theme_plugin_temperature_icon" "$PLUGIN_TEMPERATURE_ICON")
# shellcheck disable=SC2034
plugin_temperature_accent_color=$(get_tmux_option "@theme_plugin_temperature_accent_color" "$PLUGIN_TEMPERATURE_ACCENT_COLOR")
# shellcheck disable=SC2034
plugin_temperature_accent_color_icon=$(get_tmux_option "@theme_plugin_temperature_accent_color_icon" "$PLUGIN_TEMPERATURE_ACCENT_COLOR_ICON")

# Cache settings
TEMPERATURE_CACHE_TTL=$(get_tmux_option "@theme_plugin_temperature_cache_ttl" "$PLUGIN_TEMPERATURE_CACHE_TTL")
TEMPERATURE_CACHE_KEY="temperature"

# =============================================================================
# Temperature Detection Functions
# =============================================================================

# Convert Celsius to Fahrenheit
celsius_to_fahrenheit() {
    local celsius="$1"
    awk "BEGIN {printf \"%.0f\", ($celsius * 9/5) + 32}"
}

# Get temperature from specific thermal zone by type
get_temp_thermal_zone_by_type() {
    local zone_type="$1"
    
    for zone in /sys/class/thermal/thermal_zone*; do
        [[ -f "$zone/type" ]] || continue
        
        local type
        type=$(<"$zone/type")
        
        if [[ "$type" == "$zone_type" ]]; then
            local temp_file="$zone/temp"
            [[ -f "$temp_file" ]] || continue
            
            local temp_millicelsius
            temp_millicelsius=$(<"$temp_file")
            
            [[ -n "$temp_millicelsius" ]] || continue
            
            local temp
            temp=$(awk "BEGIN {printf \"%.0f\", $temp_millicelsius / 1000}")
            printf '%s' "$temp"
            return 0
        fi
    done
    
    return 1
}

# Get temperature from hwmon by sensor name
get_temp_hwmon_by_name() {
    local sensor_name="$1"
    
    for dir in /sys/class/hwmon/hwmon*; do
        [[ -d "$dir" ]] || continue
        [[ -f "$dir/name" ]] || continue
        
        local name
        name=$(<"$dir/name")
        
        if [[ "$name" == "$sensor_name" ]]; then
            # Find first temp input file
            for temp_file in "$dir"/temp*_input; do
                [[ -f "$temp_file" ]] || continue
                
                local temp_millicelsius
                temp_millicelsius=$(<"$temp_file")
                [[ -n "$temp_millicelsius" ]] || continue
                
                local temp
                temp=$(awk "BEGIN {printf \"%.0f\", $temp_millicelsius / 1000}")
                printf '%s' "$temp"
                return 0
            done
        fi
    done
    
    return 1
}

# Get temperature on macOS using osx-cpu-temp
get_temp_macos_osx_cpu_temp() {
    command -v osx-cpu-temp &>/dev/null || return 1
    
    local temp
    temp=$(osx-cpu-temp 2>/dev/null | grep -oE '[0-9]+\.?[0-9]*')
    
    [[ -n "$temp" ]] && printf '%s' "$temp" && return 0
    return 1
}

# Get temperature on macOS using powermetrics (requires sudo)
# This is mainly for reference - not practical for status bar
get_temp_macos_powermetrics() {
    # This requires sudo, so not ideal for status bar
    # Left here for completeness
    return 1
}

# Get temperature on macOS using istats (Ruby gem)
get_temp_macos_istats() {
    command -v istats &>/dev/null || return 1
    
    local temp
    temp=$(istats cpu temp 2>/dev/null | grep -oE '[0-9]+\.?[0-9]*' | head -1)
    
    [[ -n "$temp" ]] && printf '%s' "$temp" && return 0
    return 1
}

# Get temperature on macOS using smctemp
get_temp_macos_smctemp() {
    command -v smctemp &>/dev/null || return 1
    
    local temp
    temp=$(smctemp -c 2>/dev/null | grep -oE '[0-9]+\.?[0-9]*' | head -1)
    
    [[ -n "$temp" ]] && printf '%s' "$temp" && return 0
    return 1
}

# Get temperature on macOS using ioreg (battery temperature as fallback)
# This works on Apple Silicon without any external tools

# Get temperature from specific thermal zone by type
get_temp_thermal_zone_by_type() {
    local zone_type="$1"
    
    for zone in /sys/class/thermal/thermal_zone*; do
        [[ -f "$zone/type" ]] || continue
        
        local type
        type=$(<"$zone/type")
        
        if [[ "$type" == "$zone_type" ]]; then
            local temp_file="$zone/temp"
            [[ -f "$temp_file" ]] || continue
            
            local temp_millicelsius
            temp_millicelsius=$(<"$temp_file")
            
            [[ -n "$temp_millicelsius" ]] || continue
            
            local temp
            temp=$(awk "BEGIN {printf \"%.0f\", $temp_millicelsius / 1000}")
            printf '%s' "$temp"
            return 0
        fi
    done
    
    return 1
}

# Get temperature on Linux from /sys/class/thermal
get_temp_linux_sys() {
    local thermal_zone="/sys/class/thermal/thermal_zone0/temp"
    
    [[ -f "$thermal_zone" ]] || return 1
    
    local temp_millicelsius
    temp_millicelsius=$(<"$thermal_zone")
    
    [[ -n "$temp_millicelsius" ]] || return 1
    
    # Convert millicelsius to celsius
    local temp
    temp=$(awk "BEGIN {printf \"%.0f\", $temp_millicelsius / 1000}")
    
    printf '%s' "$temp"
}

# Get temperature from hwmon by sensor name
get_temp_hwmon_by_name() {
    local sensor_name="$1"
    
    for dir in /sys/class/hwmon/hwmon*; do
        [[ -d "$dir" ]] || continue
        [[ -f "$dir/name" ]] || continue
        
        local name
        name=$(<"$dir/name")
        
        if [[ "$name" == "$sensor_name" ]]; then
            # Find first temp input file
            for temp_file in "$dir"/temp*_input; do
                [[ -f "$temp_file" ]] || continue
                
                local temp_millicelsius
                temp_millicelsius=$(<"$temp_file")
                [[ -n "$temp_millicelsius" ]] || continue
                
                local temp
                temp=$(awk "BEGIN {printf \"%.0f\", $temp_millicelsius / 1000}")
                printf '%s' "$temp"
                return 0
            done
        fi
    done
    
    return 1
}

# Get temperature on Linux from /sys/class/hwmon
get_temp_linux_hwmon() {
    local hwmon_dirs=(/sys/class/hwmon/hwmon*)
    
    for dir in "${hwmon_dirs[@]}"; do
        [[ -d "$dir" ]] || continue
        
        # Look for CPU temperature (common names)
        local temp_file=""
        
        # Check for coretemp or k10temp (AMD)
        local name=""
        [[ -f "$dir/name" ]] && name=$(<"$dir/name")
        
        if [[ "$name" == "coretemp" ]] || [[ "$name" == "k10temp" ]] || [[ "$name" == "zenpower" ]]; then
            # Find temp input file
            for temp in "$dir"/temp*_input; do
                [[ -f "$temp" ]] && temp_file="$temp" && break
            done
        fi
        
        if [[ -n "$temp_file" ]]; then
            local temp_millicelsius
            temp_millicelsius=$(<"$temp_file")
            local temp
            temp=$(awk "BEGIN {printf \"%.0f\", $temp_millicelsius / 1000}")
            printf '%s' "$temp"
            return 0
        fi
    done
    
    return 1
}

# Get temperature on Linux using lm-sensors
get_temp_linux_sensors() {
    command -v sensors &>/dev/null || return 1
    
    local temp
    
    # Try to get CPU package temp first
    temp=$(sensors 2>/dev/null | grep -E "^(Package|Tctl|Tdie|CPU)" | head -1 | grep -oE '[0-9]+\.?[0-9]*' | head -1)
    
    # Fallback to any Core temp
    if [[ -z "$temp" ]]; then
        temp=$(sensors 2>/dev/null | grep "Core 0" | grep -oE '[0-9]+\.?[0-9]*' | head -1)
    fi
    
    [[ -n "$temp" ]] && printf '%s' "$temp" && return 0
    return 1
}

get_temperature() {
    # Desabilitado completamente no macOS (Apple Silicon)
    if is_macos; then
        return 0
    fi
    
    local source
    source=$(get_tmux_option "@theme_plugin_temperature_source" "$PLUGIN_TEMPERATURE_SOURCE")
    
    local temp=""
    
    case "$source" in
        cpu|coretemp)
            # CPU temperature from coretemp sensor (Intel physical cores)
            temp=$(get_temp_hwmon_by_name "coretemp") || \
            temp=$(get_temp_hwmon_by_name "k10temp") || \
            temp=$(get_temp_hwmon_by_name "zenpower") || \
            temp=$(get_temp_thermal_zone_by_type "x86_pkg_temp") || \
            temp=$(get_temp_thermal_zone_by_type "TCPU") || \
            temp=$(get_temp_hwmon_by_name "dell_smm") || \
            temp=$(get_temp_linux_hwmon)
            ;;
        cpu-pkg|x86_pkg_temp)
            # CPU package temperature (entire processor)
            temp=$(get_temp_thermal_zone_by_type "x86_pkg_temp") || \
            temp=$(get_temp_hwmon_by_name "coretemp")
            ;;
        cpu-acpi|tcpu)
            # CPU temperature via ACPI
            temp=$(get_temp_thermal_zone_by_type "TCPU")
            ;;
        nvme|ssd)
            # NVMe SSD temperature
            temp=$(get_temp_hwmon_by_name "nvme")
            ;;
        wifi|wireless|iwlwifi)
            # WiFi chip temperature
            temp=$(get_temp_hwmon_by_name "iwlwifi_1") || \
            temp=$(get_temp_thermal_zone_by_type "iwlwifi_1")
            ;;
        acpi|ambient|chassis)
            # System ambient/chassis temperature
            temp=$(get_temp_thermal_zone_by_type "INT3400 Thermal") || \
            temp=$(get_temp_linux_sys)
            ;;
        dell|dell_smm)
            # Dell system sensors
            temp=$(get_temp_hwmon_by_name "dell_smm") || \
            temp=$(get_temp_hwmon_by_name "dell_ddv")
            ;;
        auto|*)
            # Auto mode - prefer CPU temperature
            temp=$(get_temp_linux_hwmon) || \
            temp=$(get_temp_linux_sys) || \
            temp=$(get_temp_linux_sensors)
            ;;
    esac
    
    [[ -n "$temp" ]] && printf '%s' "$temp"
}

# Check if temperature reading is available
temperature_is_available() {
    local temp
    temp=$(get_temperature)
    [[ -n "$temp" ]]
}

# =============================================================================
# Plugin Interface Implementation
# =============================================================================

plugin_get_display_info() {
    local content="$1"
    local show="1"
    local accent=""
    local accent_icon=""
    local icon=""
    
    # Extract numeric value (handle both "XX°C" and "XX°F")
    local value
    value=$(echo "$content" | grep -oE '[0-9]+' | head -1)
    
    [[ -z "$value" ]] && { build_display_info "$show" "" "" ""; return; }
    
    # Get thresholds
    local warning_threshold critical_threshold
    warning_threshold=$(get_cached_option "@theme_plugin_temperature_warning_threshold" "$PLUGIN_TEMPERATURE_WARNING_THRESHOLD")
    critical_threshold=$(get_cached_option "@theme_plugin_temperature_critical_threshold" "$PLUGIN_TEMPERATURE_CRITICAL_THRESHOLD")
    
    # Check if unit is Fahrenheit and adjust thresholds accordingly
    local unit
    unit=$(get_cached_option "@theme_plugin_temperature_unit" "$PLUGIN_TEMPERATURE_UNIT")
    
    if [[ "$unit" == "F" ]]; then
        # Convert thresholds to Fahrenheit for comparison
        warning_threshold=$(celsius_to_fahrenheit "$warning_threshold")
        critical_threshold=$(celsius_to_fahrenheit "$critical_threshold")
    fi
    
    # Apply threshold colors
    if [[ "$value" -ge "$critical_threshold" ]]; then
        accent=$(get_cached_option "@theme_plugin_temperature_critical_accent_color" "$PLUGIN_TEMPERATURE_CRITICAL_ACCENT_COLOR")
        accent_icon=$(get_cached_option "@theme_plugin_temperature_critical_accent_color_icon" "$PLUGIN_TEMPERATURE_CRITICAL_ACCENT_COLOR_ICON")
        icon=$(get_cached_option "@theme_plugin_temperature_icon_hot" "$PLUGIN_TEMPERATURE_ICON_HOT")
    elif [[ "$value" -ge "$warning_threshold" ]]; then
        accent=$(get_cached_option "@theme_plugin_temperature_warning_accent_color" "$PLUGIN_TEMPERATURE_WARNING_ACCENT_COLOR")
        accent_icon=$(get_cached_option "@theme_plugin_temperature_warning_accent_color_icon" "$PLUGIN_TEMPERATURE_WARNING_ACCENT_COLOR_ICON")
    fi
    
    build_display_info "$show" "$accent" "$accent_icon" "$icon"
}

# =============================================================================
# Main Plugin Logic
# =============================================================================

load_plugin() {
    # Desabilitado completamente no macOS (Apple Silicon)
    if is_macos; then
        return 0
    fi
    
    # Get source to make cache specific per source
    local source
    source=$(get_tmux_option "@theme_plugin_temperature_source" "$PLUGIN_TEMPERATURE_SOURCE")
    local cache_key="temperature_${source}"
    
    # Check cache first
    local cached_value
    if cached_value=$(cache_get "$cache_key" "$TEMPERATURE_CACHE_TTL"); then
        printf '%s' "$cached_value"
        return 0
    fi
    local temp
    temp=$(get_temperature)
    if [[ -z "$temp" ]]; then
        # Temperature not available
        return 0
    fi
    # Get unit preference
    local unit
    unit=$(get_tmux_option "@theme_plugin_temperature_unit" "$PLUGIN_TEMPERATURE_UNIT")
    local result
    if [[ "$unit" == "F" ]]; then
        local temp_f
        temp_f=$(celsius_to_fahrenheit "$temp")
        result="${temp_f}°F"
    else
        result="${temp}°C"
    fi
    cache_set "$cache_key" "$result"
    printf '%s' "$result"
}

# Only run if executed directly (not sourced)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    load_plugin
fi
