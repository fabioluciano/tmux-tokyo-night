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

# Source defaults to get separator values
# shellcheck source=src/defaults.sh
. "$CURRENT_DIR/defaults.sh"

# =============================================================================
# Configuration
# =============================================================================
WHITE_COLOR="${RENDER_WHITE:-#ffffff}"
BG_HIGHLIGHT="${RENDER_BG_HIGHLIGHT:-#292e42}"
TRANSPARENT="${RENDER_TRANSPARENT:-false}"
PALETTE_SERIALIZED="${RENDER_PALETTE:-}"
PLUGINS_CONFIG="${1:-}"

# Read separator directly from tmux with proper defaults
RIGHT_SEPARATOR=$(get_tmux_option "@theme_right_separator" "$THEME_DEFAULT_RIGHT_SEPARATOR")
RIGHT_SEPARATOR_INVERSE=$(get_tmux_option "@theme_right_separator_inverse" "$THEME_DEFAULT_RIGHT_SEPARATOR_INVERSE")

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
# Plugin Display Info Query - Optimized
# =============================================================================

# Cache for plugin display functions - avoids re-sourcing plugins
declare -A _PLUGIN_HAS_DISPLAY_INFO=()

# Query a plugin for its display info
# If the plugin defines plugin_get_display_info(), call it
# Otherwise return default values (show=1, no color/icon overrides)
#
# Output format: "show:accent:accent_icon:icon"
#
# Optimization: Source plugin once and cache whether it has the function
query_plugin_display_info() {
    local plugin_name="$1"
    local plugin_script="$2"
    local content="$3"
    
    # Check cache first
    local cache_key="$plugin_name"
    
    if [[ -z "${_PLUGIN_HAS_DISPLAY_INFO[$cache_key]+isset}" ]]; then
        # First time - source and check
        # shellcheck source=/dev/null
        . "$plugin_script" 2>/dev/null
        
        if declare -f plugin_get_display_info &>/dev/null; then
            _PLUGIN_HAS_DISPLAY_INFO[$cache_key]="1"
        else
            _PLUGIN_HAS_DISPLAY_INFO[$cache_key]="0"
        fi
    elif [[ "${_PLUGIN_HAS_DISPLAY_INFO[$cache_key]}" == "1" ]]; then
        # Re-source only if plugin has display info function
        # shellcheck source=/dev/null
        . "$plugin_script" 2>/dev/null
    fi
    
    # Call display info function if available
    if [[ "${_PLUGIN_HAS_DISPLAY_INFO[$cache_key]}" == "1" ]]; then
        plugin_get_display_info "$content"
    else
        # Default: show, no overrides
        printf '1:::'
    fi
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

    # Execute plugin to get content - plugins handle their own environment
    content=$(bash "$plugin_script" 2>/dev/null) || content=""
    
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
    display_info=$(query_plugin_display_info "$name" "$plugin_script" "$content")
    
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
# Render Output - Optimized
# =============================================================================

total=${#PLUGIN_NAMES[@]}
[[ $total -eq 0 ]] && exit 0

output=""

for ((i=0; i<total; i++)); do
    name="${PLUGIN_NAMES[$i]}"
    content="${PLUGIN_CONTENTS[$i]}"
    accent="${PLUGIN_ACCENTS[$i]}"
    accent_icon="${PLUGIN_ACCENT_ICONS[$i]}"
    icon="${PLUGIN_ICONS[$i]}"
    
    is_last=$([[ $i -eq $((total - 1)) ]] && echo "1" || echo "0")
    
    # Plugins handle their own formatting and padding needs
    
    # Build separators inline (avoiding function call overhead)
    if [[ "$TRANSPARENT" == "true" ]]; then
        sep_icon_start="#[fg=${accent_icon},bg=default]${RIGHT_SEPARATOR}#[none]"
    else
        sep_icon_start="#[fg=${accent_icon},bg=${BG_HIGHLIGHT}]${RIGHT_SEPARATOR}#[none]"
    fi
    
    sep_icon_end="#[fg=${accent},bg=${accent_icon}]${RIGHT_SEPARATOR}#[none]"
    
    # Build icon section inline
    icon_output="${sep_icon_start}#[fg=${WHITE_COLOR},bg=${accent_icon}]${icon} ${sep_icon_end}"
    
    # Build content section - for last plugin, just end cleanly with no separator
    if [[ "$is_last" == "1" ]]; then
        output+="${icon_output}#[fg=${WHITE_COLOR},bg=${accent}] ${content} "
    else
        content_output="#[fg=${WHITE_COLOR},bg=${accent}] ${content} #[none]"
        if [[ "$TRANSPARENT" == "true" ]]; then
            sep_end="#[fg=${accent},bg=default]${RIGHT_SEPARATOR_INVERSE}#[bg=default]"
        else
            sep_end="#[fg=${BG_HIGHLIGHT},bg=${accent}]${RIGHT_SEPARATOR}#[bg=${BG_HIGHLIGHT}]"
        fi
        output+="${icon_output}${content_output}${sep_end}"
    fi
done

printf '%s' "$output"
