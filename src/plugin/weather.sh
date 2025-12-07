#!/usr/bin/env bash
# =============================================================================
# Plugin: weather
# Description: Display weather information from wttr.in API
# Dependencies: curl, jq (optional, for auto location detection)
# =============================================================================
#
# Configuration options:
#   @powerkit_plugin_weather_icon            - Plugin icon (default: 󰖐)
#   @powerkit_plugin_weather_format          - Display format (default: "compact")
#                                           Predefined formats:
#                                             "compact"  - 25° ☀️
#                                             "full"     - 25°C ☀️ H:73%
#                                             "minimal"  - 25°
#                                             "detailed" - São Paulo: 25°C ☀️
#                                           Custom format using wttr.in placeholders:
#                                             %t - temperature, %c - condition icon
#                                             %h - humidity, %w - wind, %l - location
#                                             %C - condition text, %p - precipitation
#   @powerkit_plugin_weather_location        - Location (default: auto-detect by IP)
#   @powerkit_plugin_weather_unit            - Unit: "m" (metric), "u" (USCS), "M" (metric m/s)
#   @powerkit_plugin_weather_cache_ttl       - Cache TTL in seconds (default: 900)
#
# Examples:
#   set -g @powerkit_plugin_weather_format "compact"
#   set -g @powerkit_plugin_weather_format "full"
#   set -g @powerkit_plugin_weather_format "%t %C"  # Custom: "25°C Sunny"
# =============================================================================

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck source=src/plugin_bootstrap.sh
. "$ROOT_DIR/../plugin_bootstrap.sh"

# =============================================================================
# Plugin Configuration
# =============================================================================

# Initialize cache (DRY - sets CACHE_KEY and CACHE_TTL automatically)
plugin_init "weather"
WEATHER_LOCATION_CACHE_KEY="weather_location"
WEATHER_LOCATION_CACHE_TTL="3600"  # 1 hour for location

# Plugin-specific options
plugin_weather_location=$(get_tmux_option "@powerkit_plugin_weather_location" "$POWERKIT_PLUGIN_WEATHER_LOCATION")
plugin_weather_unit=$(get_tmux_option "@powerkit_plugin_weather_unit" "$POWERKIT_PLUGIN_WEATHER_UNIT")
plugin_weather_format=$(get_tmux_option "@powerkit_plugin_weather_format" "$POWERKIT_PLUGIN_WEATHER_FORMAT")

# =============================================================================
# Predefined Format Templates
# =============================================================================
# These use wttr.in format placeholders
# See: https://wttr.in/:help for all available placeholders
# =============================================================================

# Resolve format string from predefined name or use custom format
resolve_format() {
    local format="$1"
    
    case "$format" in
        compact)
            # Temperature + condition icon (e.g., "25° ☀️")
            printf '%s' '%t %c  '
            ;;
        full)
            # Temperature + icon + humidity (e.g., "25°C ☀️ H:73%")
            printf '%s' '%t %c   H:%h'
            ;;
        minimal)
            # Just temperature (e.g., "25°")
            printf '%s' '%t'
            ;;
        detailed)
            # Location + temperature + icon (e.g., "São Paulo: 25°C ☀️")
            printf '%s' '%l: %t %c  '
            ;;
        *)
            # Custom format - use as-is
            printf '%s' "$format"
            ;;
    esac
}

# =============================================================================
# Helper Functions
# =============================================================================

# -----------------------------------------------------------------------------
# Check if curl is available
# Returns: 0 if available, 1 otherwise
# -----------------------------------------------------------------------------
weather_check_dependencies() {
    command -v curl &>/dev/null
}

# -----------------------------------------------------------------------------
# Detect location via IP (cached separately with longer TTL)
# Returns: Location string
# -----------------------------------------------------------------------------
weather_detect_location() {
    local cached_location
    
    # Try cache first (location doesn't change often)
    if cached_location=$(cache_get "$WEATHER_LOCATION_CACHE_KEY" "$WEATHER_LOCATION_CACHE_TTL"); then
        printf '%s' "$cached_location"
        return 0
    fi
    
    # Need jq for location detection
    if ! command -v jq &>/dev/null; then
        printf ''
        return 1
    fi
    
    local location
    location=$(curl -s --connect-timeout 5 --max-time 10 http://ip-api.com/json 2>/dev/null | \
        jq -r '"\(.city), \(.country)"' 2>/dev/null)
    
    if [[ -n "$location" && "$location" != "null, null" && "$location" != ", " ]]; then
        cache_set "$WEATHER_LOCATION_CACHE_KEY" "$location"
        printf '%s' "$location"
        return 0
    fi
    
    printf ''
    return 1
}

# -----------------------------------------------------------------------------
# Fetch weather data from wttr.in
# Arguments:
#   $1 - Location (optional)
# Returns: Weather string
# -----------------------------------------------------------------------------
weather_fetch() {
    local location="$1"
    local url
    
    # Resolve format from predefined name or custom format
    local resolved_format
    resolved_format=$(resolve_format "$plugin_weather_format")
    
    # Build URL - if no location, wttr.in uses IP-based location
    if [[ -n "$location" ]]; then
        # URL encode the location properly using simple sed replacement
        local encoded_location
        encoded_location=$(printf '%s' "$location" | sed 's/ /%20/g; s/,/%2C/g')
        url="wttr.in/${encoded_location}?"
    else
        url="wttr.in/?"
    fi
    
    # Add unit parameter if specified
    [[ -n "$plugin_weather_unit" ]] && url+="${plugin_weather_unit}&"
    
    # URL encode the format string
    local encoded_format
    encoded_format=$(printf '%s' "$resolved_format" | sed 's/%/%25/g; s/ /%20/g; s/:/%3A/g; s/+/%2B/g')
    url+="format=${encoded_format}"
    
    local weather
    weather=$(curl -sL --connect-timeout 5 --max-time 10 "$url" 2>/dev/null)
    
    # Clean up the response
    # - Remove trailing % that wttr.in adds at the end
    # - Trim whitespace
    # - Remove Unicode variation selectors (U+FE0E, U+FE0F) that cause width issues in tmux
    weather=$(printf '%s' "$weather" | sed 's/%$//; s/^[[:space:]]*//; s/[[:space:]]*$//')
    # Remove variation selectors using perl if available, otherwise use sed
    if command -v perl &>/dev/null; then
        weather=$(printf '%s' "$weather" | perl -CS -pe 's/\x{FE0E}|\x{FE0F}//g')
    fi
    
    # Validate response
    if [[ -z "$weather" || "$weather" == *"Unknown"* || "$weather" == *"ERROR"* || ${#weather} -gt 100 ]]; then
        printf 'N/A'
        return 1
    fi
    
    printf '%s' "$weather"
}

# =============================================================================
# Plugin Interface Implementation
# =============================================================================

# Function to inform the plugin type to the renderer
plugin_get_type() {
    printf 'conditional'
}

# =============================================================================
# Main Plugin Logic
# =============================================================================

load_plugin() {
    # Check dependencies - fail silently if curl is not available
    if ! weather_check_dependencies; then
        return 0
    fi
    
    # Try cache first
    local cached_value
    if cached_value=$(cache_get "$CACHE_KEY" "$CACHE_TTL"); then
        # Don't return cached N/A
        if [[ "$cached_value" != "N/A" ]]; then
            printf '%s' "$cached_value"
            return 0
        fi
    fi
    
    # Determine location - only use configured location, otherwise let wttr.in auto-detect
    local location=""
    if [[ -n "$plugin_weather_location" ]]; then
        location="$plugin_weather_location"
    fi
    
    # Fetch weather
    local result
    result=$(weather_fetch "$location")
    
    # Cache and output
    cache_set "$CACHE_KEY" "$result"
    printf '%s' "$result"
}

# Only run if executed directly (not sourced)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    load_plugin
fi
