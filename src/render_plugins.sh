#!/usr/bin/env bash
# =============================================================================
# Unified Plugin Renderer
# Renders all plugins in a single pass to ensure consistent separator handling.
#
# This script queries each plugin for its display behavior using the
# plugin_get_display_info() function if available.
#
# Usage: render_plugins.sh <plugins_config>
# Where plugins_config is a semicolon-separated list of plugin configs:
#   "name:accent:accent_icon:icon:type;name2:accent2:accent_icon2:icon2:type;..."
#
# Types: static, conditional, datetime
#
# Environment variables:
#   RENDER_WHITE - White/foreground color
#   RENDER_BG_HIGHLIGHT - Background highlight color
#   RENDER_TRANSPARENT - "true" or "false"
#   RENDER_PALETTE - Serialized palette for color lookups
# =============================================================================

CURRENT_DIR="$(cd "$(dirname "$0")" && pwd)"

# shellcheck source=src/utils.sh
. "$CURRENT_DIR/utils.sh"
# shellcheck source=src/separators.sh
. "$CURRENT_DIR/separators.sh"

# =============================================================================
# Configuration
# =============================================================================
WHITE_COLOR="${RENDER_WHITE:-#ffffff}"
BG_HIGHLIGHT="${RENDER_BG_HIGHLIGHT:-#292e42}"
TRANSPARENT="${RENDER_TRANSPARENT:-false}"
PALETTE_SERIALIZED="${RENDER_PALETTE:-}"
PLUGINS_CONFIG="${1:-}"

# Read separator directly from tmux
RIGHT_SEPARATOR=$(get_tmux_option "@theme_right_separator" $'\ue0b2')
RIGHT_SEPARATOR_INVERSE=$(get_tmux_option "@theme_transparent_right_separator_inverse" $'\ue0d6')

# =============================================================================
# Palette Helper
# =============================================================================
# Parse palette once into associative array for fast lookups
declare -A _PALETTE_MAP
_parse_palette() {
    [[ -z "$PALETTE_SERIALIZED" ]] && return
    local IFS=';'
    local entry
    for entry in $PALETTE_SERIALIZED; do
        [[ -z "$entry" ]] && continue
        local key="${entry%%=*}"
        local value="${entry#*=}"
        _PALETTE_MAP["$key"]="$value"
    done
}
_parse_palette

get_palette_color() {
    local color_name="$1"
    printf '%s' "${_PALETTE_MAP[$color_name]:-$color_name}"
}

# =============================================================================
# Plugin Display Info Query
# =============================================================================

# Query a plugin for its display info
# If the plugin defines plugin_get_display_info(), call it
# Otherwise return default values (show=1, no color/icon overrides)
#
# Output format: "show:accent:accent_icon:icon"
query_plugin_display_info() {
    local plugin_script="$1"
    local content="$2"
    
    # Source the plugin to get access to its functions
    # Use a subshell to avoid polluting our environment
    local display_info
    display_info=$(
        # shellcheck source=/dev/null
        # Source the plugin
        . "$plugin_script" 2>/dev/null
        
        # Check if plugin defines the display info function
        if declare -f plugin_get_display_info &>/dev/null; then
            plugin_get_display_info "$content"
        else
            # Default: show, no overrides
            printf '1:::'
        fi
    )
    
    printf '%s' "$display_info"
}

# =============================================================================
# Main Logic
# =============================================================================

# Arrays to store plugins that will be rendered
declare -a PLUGIN_NAMES=()
declare -a PLUGIN_CONTENTS=()
declare -a PLUGIN_ACCENTS=()
declare -a PLUGIN_ACCENT_ICONS=()
declare -a PLUGIN_ICONS=()

# Parse plugins config and execute each
IFS=';' read -ra PLUGIN_CONFIGS <<< "$PLUGINS_CONFIG"

for config in "${PLUGIN_CONFIGS[@]}"; do
    [[ -z "$config" ]] && continue
    
    # Parse config: name:accent:accent_icon:icon:type
    IFS=':' read -r name accent accent_icon icon plugin_type <<< "$config"
    
    plugin_script="${CURRENT_DIR}/plugin/${name}.sh"
    [[ ! -f "$plugin_script" ]] && continue
    
    # shellcheck source=/dev/null
    
    # Execute plugin to get content
    content=$("$plugin_script" 2>/dev/null) || content=""
    
    # Handle special types first
    case "$plugin_type" in
        conditional)
            # Conditional plugins: only render if has content
            [[ -z "$content" ]] && continue
            ;;
        datetime)
            # datetime returns strftime format string - execute date to get actual value
            content=$(date +"$content" 2>/dev/null) || content=""
            ;;
    esac
    
    # Query the plugin for display info (show/hide, color overrides)
    display_info=$(query_plugin_display_info "$plugin_script" "$content")
    
    # Parse display info: "show:accent:accent_icon:icon"
    IFS=':' read -r should_show override_accent override_accent_icon override_icon <<< "$display_info"
    
    # Check if plugin wants to hide
    [[ "$should_show" == "0" ]] && continue
    
    # Apply color overrides if provided
    if [[ -n "$override_accent" ]]; then
        accent=$(get_palette_color "$override_accent")
    fi
    if [[ -n "$override_accent_icon" ]]; then
        accent_icon=$(get_palette_color "$override_accent_icon")
    fi
    if [[ -n "$override_icon" ]]; then
        icon="$override_icon"
    fi
    
    # Add to render list
    PLUGIN_NAMES+=("$name")
    PLUGIN_CONTENTS+=("$content")
    PLUGIN_ACCENTS+=("$accent")
    PLUGIN_ACCENT_ICONS+=("$accent_icon")
    PLUGIN_ICONS+=("$icon")
done

# =============================================================================
# Render Output
# =============================================================================

total=${#PLUGIN_NAMES[@]}
[[ $total -eq 0 ]] && exit 0

output=""

for ((i=0; i<total; i++)); do
    content="${PLUGIN_CONTENTS[$i]}"
    accent="${PLUGIN_ACCENTS[$i]}"
    accent_icon="${PLUGIN_ACCENT_ICONS[$i]}"
    icon="${PLUGIN_ICONS[$i]}"
    
    is_last=$([[ $i -eq $((total - 1)) ]] && echo "1" || echo "0")
    
    # Build separators
    sep_icon_start=$(build_separator_icon_start "$accent_icon" "$BG_HIGHLIGHT" "$RIGHT_SEPARATOR" "$TRANSPARENT")
    sep_icon_end=$(build_separator_icon_end "$accent" "$accent_icon" "$RIGHT_SEPARATOR")
    
    # Build icon section
    icon_output=$(build_icon_section "$sep_icon_start" "$sep_icon_end" "$WHITE_COLOR" "$accent_icon" "$icon")
    
    # Build content section - for last plugin, just end cleanly with no separator
    if [[ "$is_last" == "1" ]]; then
        content_output="#[fg=${WHITE_COLOR},bg=${accent}] ${content}"
        output+="${icon_output}${content_output}"
    else
        content_output=$(build_content_section "$WHITE_COLOR" "$accent" "$content" "$is_last")
        sep_end=$(build_separator_end "$accent" "$BG_HIGHLIGHT" "$RIGHT_SEPARATOR" "$TRANSPARENT" "$RIGHT_SEPARATOR_INVERSE")
        output+="${icon_output}${content_output}${sep_end}"
    fi
done

printf '%s' "$output"
