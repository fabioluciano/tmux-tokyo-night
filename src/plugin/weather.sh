#!/usr/bin/env bash
# Plugin: weather - Display weather information from wttr.in API

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$ROOT_DIR/../plugin_bootstrap.sh"

plugin_init "weather"
WEATHER_LOCATION_CACHE_KEY="weather_location"
WEATHER_LOCATION_CACHE_TTL="3600"

plugin_get_type() { printf 'conditional'; }

resolve_format() {
    case "$1" in
        compact)  printf '%s' '%t %c' ;;
        full)     printf '%s' '%t %c H:%h' ;;
        minimal)  printf '%s' '%t' ;;
        detailed) printf '%s' '%l: %t %c' ;;
        *)        printf '%s' "$1" ;;
    esac
}

weather_detect_location() {
    local cached_location
    if cached_location=$(cache_get "$WEATHER_LOCATION_CACHE_KEY" "$WEATHER_LOCATION_CACHE_TTL"); then
        printf '%s' "$cached_location"
        return 0
    fi
    
    command -v jq &>/dev/null || return 1
    
    local location
    location=$(curl -s --connect-timeout 5 --max-time 10 http://ip-api.com/json 2>/dev/null | \
        jq -r '"\(.city), \(.country)"' 2>/dev/null)
    
    if [[ -n "$location" && "$location" != "null, null" && "$location" != ", " ]]; then
        cache_set "$WEATHER_LOCATION_CACHE_KEY" "$location"
        printf '%s' "$location"
        return 0
    fi
    return 1
}

weather_fetch() {
    local location="$1"
    local format unit
    format=$(get_cached_option "@powerkit_plugin_weather_format" "$POWERKIT_PLUGIN_WEATHER_FORMAT")
    unit=$(get_cached_option "@powerkit_plugin_weather_unit" "$POWERKIT_PLUGIN_WEATHER_UNIT")
    
    local resolved_format
    resolved_format=$(resolve_format "$format")
    
    local url="wttr.in/"
    [[ -n "$location" ]] && url+="$(printf '%s' "$location" | sed 's/ /%20/g; s/,/%2C/g')"
    url+="?"
    [[ -n "$unit" ]] && url+="${unit}&"
    url+="format=$(printf '%s' "$resolved_format" | sed 's/%/%25/g; s/ /%20/g; s/:/%3A/g; s/+/%2B/g')"
    
    local weather
    weather=$(curl -sL --connect-timeout 5 --max-time 10 "$url" 2>/dev/null)
    weather=$(printf '%s' "$weather" | sed 's/%$//; s/^[[:space:]]*//; s/[[:space:]]*$//')
    command -v perl &>/dev/null && weather=$(printf '%s' "$weather" | perl -CS -pe 's/\x{FE0E}|\x{FE0F}//g')
    
    [[ -z "$weather" || "$weather" == *"Unknown"* || "$weather" == *"ERROR"* || ${#weather} -gt 100 ]] && { printf 'N/A'; return 1; }
    printf '%s' "$weather"
}

plugin_get_display_info() {
    local content="${1:-}"
    [[ -n "$content" && "$content" != "N/A" ]] && echo "1:::" || echo "0:::"
}

load_plugin() {
    command -v curl &>/dev/null || return 0
    
    local cached_value
    if cached_value=$(cache_get "$CACHE_KEY" "$CACHE_TTL"); then
        [[ "$cached_value" != "N/A" ]] && { printf '%s' "$cached_value"; return 0; }
    fi
    
    local location
    location=$(get_cached_option "@powerkit_plugin_weather_location" "$POWERKIT_PLUGIN_WEATHER_LOCATION")
    
    local result
    result=$(weather_fetch "$location")
    
    cache_set "$CACHE_KEY" "$result"
    printf '%s' "$result"
}

[[ "${BASH_SOURCE[0]}" == "${0}" ]] && load_plugin || true
