#!/usr/bin/env bash
# =============================================================================
# Threshold Plugin Wrapper
# Renders a plugin segment with dynamic colors based on value thresholds
# and optional conditional display based on value ranges
#
# Usage: threshold_plugin.sh <plugin_name> <args...>
#
# This wrapper enables two powerful features for any plugin:
#   1. Dynamic colors: Change plugin colors based on the numeric value
#   2. Conditional display: Only show plugin when value meets threshold
#
# Configuration options (set in tmux.conf):
#   @theme_plugin_<name>_display_threshold     - Value threshold for display
#   @theme_plugin_<name>_display_condition     - Condition: le, lt, ge, gt, eq, always
#   @theme_plugin_<name>_threshold_mode        - Color mode: ascending, descending
#   @theme_plugin_<name>_critical_threshold    - Critical level threshold
#   @theme_plugin_<name>_warning_threshold     - Warning level threshold
#   @theme_plugin_<name>_critical_color        - Color for critical level
#   @theme_plugin_<name>_critical_color_icon   - Icon color for critical level
#   @theme_plugin_<name>_warning_color         - Color for warning level
#   @theme_plugin_<name>_warning_color_icon    - Icon color for warning level
#   @theme_plugin_<name>_normal_color          - Color for normal level
#   @theme_plugin_<name>_normal_color_icon     - Icon color for normal level
# =============================================================================

CURRENT_DIR="$(cd "$(dirname "$0")" && pwd)"

# shellcheck source=src/utils.sh
. "$CURRENT_DIR/utils.sh"

# Arguments passed from theme.sh
PLUGIN_NAME="${1:-}"
SEP_ICON_START_TEMPLATE="${2:-}"
SEP_ICON_END_TEMPLATE="${3:-}"
SEP_END_TEMPLATE="${4:-}"
DEFAULT_ACCENT_COLOR="${5:-}"
DEFAULT_ACCENT_COLOR_ICON="${6:-}"
PLUGIN_ICON="${7:-}"
IS_LAST="${8:-0}"
WHITE_COLOR="${9:-}"
BG_HIGHLIGHT="${10:-}"
RIGHT_SEPARATOR="${11:-}"
TRANSPARENT="${12:-false}"
RIGHT_SEPARATOR_INVERSE="${13:-}"
# Palette colors passed as arguments for threshold coloring
PALETTE_SERIALIZED="${14:-}"

PLUGIN_SCRIPT="${CURRENT_DIR}/plugin/${PLUGIN_NAME}.sh"

[[ ! -f "$PLUGIN_SCRIPT" ]] && exit 0

# Execute plugin and get content
content=$("$PLUGIN_SCRIPT" 2>/dev/null) || content=""

# Exit if no content
[[ -z "$content" ]] && exit 0

# Extract numeric value from content (for threshold checks)
numeric_value="${content//[!0-9]/}"

# Get threshold configuration
display_threshold=$(get_tmux_option "@theme_plugin_${PLUGIN_NAME}_display_threshold" "")
display_condition=$(get_tmux_option "@theme_plugin_${PLUGIN_NAME}_display_condition" "always")

# Check if plugin should be displayed based on threshold
if [[ -n "$display_threshold" ]] && [[ "$display_condition" != "always" ]]; then
    if ! check_display_threshold "$numeric_value" "$display_threshold" "$display_condition"; then
        exit 0
    fi
fi

# Get threshold color configuration
threshold_mode=$(get_tmux_option "@theme_plugin_${PLUGIN_NAME}_threshold_mode" "")

# Determine final colors
final_accent_color="$DEFAULT_ACCENT_COLOR"
final_accent_color_icon="$DEFAULT_ACCENT_COLOR_ICON"

if [[ -n "$threshold_mode" ]] && [[ -n "$numeric_value" ]]; then
    # Get threshold values
    critical_threshold=$(get_tmux_option "@theme_plugin_${PLUGIN_NAME}_critical_threshold" "10")
    warning_threshold=$(get_tmux_option "@theme_plugin_${PLUGIN_NAME}_warning_threshold" "30")
    
    # Get custom colors for each level
    critical_color=$(get_tmux_option "@theme_plugin_${PLUGIN_NAME}_critical_color" "red")
    critical_color_icon=$(get_tmux_option "@theme_plugin_${PLUGIN_NAME}_critical_color_icon" "red1")
    warning_color=$(get_tmux_option "@theme_plugin_${PLUGIN_NAME}_warning_color" "yellow")
    warning_color_icon=$(get_tmux_option "@theme_plugin_${PLUGIN_NAME}_warning_color_icon" "orange")
    normal_color=$(get_tmux_option "@theme_plugin_${PLUGIN_NAME}_normal_color" "green")
    normal_color_icon=$(get_tmux_option "@theme_plugin_${PLUGIN_NAME}_normal_color_icon" "green1")
    
    # Get the appropriate color based on mode
    if [[ "$threshold_mode" == "descending" ]]; then
        # Descending: low values are bad (battery)
        selected_color=$(get_threshold_color_descending "$numeric_value" \
            "$critical_threshold" "$warning_threshold" \
            "$critical_color" "$warning_color" "$normal_color")
        selected_color_icon=$(get_threshold_color_descending "$numeric_value" \
            "$critical_threshold" "$warning_threshold" \
            "$critical_color_icon" "$warning_color_icon" "$normal_color_icon")
    else
        # Ascending: high values are bad (CPU, memory, disk)
        selected_color=$(get_threshold_color_ascending "$numeric_value" \
            "$critical_threshold" "$warning_threshold" \
            "$normal_color" "$warning_color" "$critical_color")
        selected_color_icon=$(get_threshold_color_ascending "$numeric_value" \
            "$critical_threshold" "$warning_threshold" \
            "$normal_color_icon" "$warning_color_icon" "$critical_color_icon")
    fi
    
    # Resolve palette colors from serialized string
    # Format: key1=value1;key2=value2;...
    if [[ -n "$PALETTE_SERIALIZED" ]]; then
        # Extract color value from serialized palette using grep/sed
        get_palette_color() {
            local color_name="$1"
            local default="$2"
            local result
            result=$(echo "$PALETTE_SERIALIZED" | grep -o "${color_name}=[^;]*" | cut -d'=' -f2)
            printf '%s' "${result:-$default}"
        }
        
        final_accent_color=$(get_palette_color "$selected_color" "$DEFAULT_ACCENT_COLOR")
        final_accent_color_icon=$(get_palette_color "$selected_color_icon" "$DEFAULT_ACCENT_COLOR_ICON")
    fi
fi

# Build separators with final colors
if [[ "$TRANSPARENT" == "true" ]]; then
    sep_icon_start="#[fg=${final_accent_color_icon},bg=default]${RIGHT_SEPARATOR}#[none]"
    sep_icon_end="#[fg=${final_accent_color},bg=${final_accent_color_icon}]${RIGHT_SEPARATOR}#[none]"
    sep_end="#[fg=${final_accent_color},bg=default]${RIGHT_SEPARATOR_INVERSE}#[none]"
else
    sep_icon_start="#[fg=${final_accent_color_icon},bg=${BG_HIGHLIGHT}]${RIGHT_SEPARATOR}#[none]"
    sep_icon_end="#[fg=${final_accent_color},bg=${final_accent_color_icon}]${RIGHT_SEPARATOR}#[none]"
    sep_end="#[fg=${BG_HIGHLIGHT},bg=${final_accent_color}]${RIGHT_SEPARATOR}#[none]"
fi

# Build icon section
icon_output="${sep_icon_start}#[fg=${WHITE_COLOR},bg=${final_accent_color_icon}]${PLUGIN_ICON}${sep_icon_end}"

# Build content section
content_output="#[fg=${WHITE_COLOR},bg=${final_accent_color}] ${content}#[none]"

# Combine with or without separator
if [[ "$IS_LAST" != "1" ]]; then
    printf '%s' "${icon_output}${content_output} ${sep_end}"
else
    printf '%s' "${icon_output}${content_output} "
fi
