#!/usr/bin/env bash
# =============================================================================
# Plugin: timezones
# Description: Display time in multiple time zones
# Dependencies: None (uses TZ environment variable)
# =============================================================================

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$ROOT_DIR/../plugin_bootstrap.sh"

plugin_init "timezones"

# =============================================================================
# Timezone Functions
# =============================================================================

# Common timezone aliases for convenience
declare -A TZ_ALIASES=(
    ["nyc"]="America/New_York"
    ["la"]="America/Los_Angeles"
    ["chicago"]="America/Chicago"
    ["denver"]="America/Denver"
    ["london"]="Europe/London"
    ["paris"]="Europe/Paris"
    ["berlin"]="Europe/Berlin"
    ["moscow"]="Europe/Moscow"
    ["tokyo"]="Asia/Tokyo"
    ["shanghai"]="Asia/Shanghai"
    ["beijing"]="Asia/Shanghai"
    ["singapore"]="Asia/Singapore"
    ["sydney"]="Australia/Sydney"
    ["dubai"]="Asia/Dubai"
    ["mumbai"]="Asia/Kolkata"
    ["delhi"]="Asia/Kolkata"
    ["saopaulo"]="America/Sao_Paulo"
    ["utc"]="UTC"
    ["gmt"]="GMT"
)

# Resolve timezone (supports aliases)
resolve_timezone() {
    local tz="$1"
    local lower_tz="${tz,,}"
    echo "${TZ_ALIASES[$lower_tz]:-$tz}"
}

# Get abbreviated timezone label
get_tz_label() {
    local tz="$1"
    local show_label
    show_label=$(get_cached_option "@powerkit_plugin_timezones_show_label" "$POWERKIT_PLUGIN_TIMEZONES_SHOW_LABEL")
    
    [[ "$show_label" != "true" ]] && return
    
    local label
    case "$tz" in
        America/New_York)    label="NYC" ;;
        America/Los_Angeles) label="LA" ;;
        America/Chicago)     label="CHI" ;;
        Europe/London)       label="LON" ;;
        Europe/Paris)        label="PAR" ;;
        Europe/Berlin)       label="BER" ;;
        Asia/Tokyo)          label="TYO" ;;
        Asia/Shanghai)       label="SHA" ;;
        Asia/Singapore)      label="SIN" ;;
        Australia/Sydney)    label="SYD" ;;
        UTC|GMT)             label="$tz" ;;
        *)
            label="${tz##*/}"
            label="${label:0:3}"
            label="${label^^}"
            ;;
    esac
    
    echo "$label"
}

# Format time for a specific timezone
format_tz_time() {
    local tz="$1"
    local format
    format=$(get_cached_option "@powerkit_plugin_timezones_format" "$POWERKIT_PLUGIN_TIMEZONES_FORMAT")
    
    local resolved_tz
    resolved_tz=$(resolve_timezone "$tz")
    
    local time_str label_str=""
    time_str=$(TZ="$resolved_tz" date +"$format" 2>/dev/null)
    
    local label
    label=$(get_tz_label "$resolved_tz")
    [[ -n "$label" ]] && label_str="$label "
    
    echo "${label_str}${time_str}"
}

# =============================================================================
# Plugin Interface
# =============================================================================

plugin_get_type() { printf 'conditional'; }

plugin_get_display_info() {
    local content="$1"
    [[ -n "$content" ]] && echo "1:::" || echo "0:::"
}

# =============================================================================
# Main
# =============================================================================

load_plugin() {
    local zones separator
    zones=$(get_cached_option "@powerkit_plugin_timezones_zones" "$POWERKIT_PLUGIN_TIMEZONES_ZONES")
    separator=$(get_cached_option "@powerkit_plugin_timezones_separator" "$POWERKIT_PLUGIN_TIMEZONES_SEPARATOR")
    
    [[ -z "$zones" ]] && return 0
    
    local result="" first=1
    IFS=',' read -ra tz_array <<< "$zones"
    
    for tz in "${tz_array[@]}"; do
        tz="${tz#"${tz%%[![:space:]]*}"}"
        tz="${tz%"${tz##*[![:space:]]}"}"
        
        [[ -z "$tz" ]] && continue
        
        local time_str
        time_str=$(format_tz_time "$tz")
        
        if [[ $first -eq 1 ]]; then
            result="$time_str"
            first=0
        else
            result+="${separator}${time_str}"
        fi
    done
    
    printf '%s' "$result"
}

[[ "${BASH_SOURCE[0]}" == "${0}" ]] && load_plugin || true
