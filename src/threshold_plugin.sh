#!/usr/bin/env bash
# =============================================================================
# Threshold Plugin Wrapper
# Renders a plugin segment with dynamic colors based on value thresholds
# and optional conditional display based on value ranges
#
# Features:
#   1. Dynamic colors: Change plugin colors based on the numeric value
#   2. Conditional display: Only show plugin when value meets threshold
#   3. Plugin-specific low threshold: Simple low/normal state with custom icon/colors
#
# Configuration options (set in tmux.conf):
#   @theme_plugin_<name>_threshold_mode        - Color mode: ascending, descending
#   @theme_plugin_<name>_display_threshold     - Value threshold for display
#   @theme_plugin_<name>_display_condition     - Condition: le, lt, ge, gt, eq, always
#   @theme_plugin_<name>_critical_threshold    - Critical level threshold
#   @theme_plugin_<name>_warning_threshold     - Warning level threshold
#   @theme_plugin_<name>_critical_color        - Color for critical level
#   @theme_plugin_<name>_warning_color         - Color for warning level
#   @theme_plugin_<name>_normal_color          - Color for normal level
#
# Plugin-specific low threshold (alternative to threshold_mode):
#   @theme_plugin_<name>_low_threshold         - Simple threshold for low state
#   @theme_plugin_<name>_low_accent_color      - Color when value <= low_threshold
#   @theme_plugin_<name>_low_accent_color_icon - Icon color when value <= low_threshold
#   @theme_plugin_<name>_icon_low              - Icon to use when value <= low_threshold
# =============================================================================

CURRENT_DIR="$(cd "$(dirname "$0")" && pwd)"

# shellcheck source=src/utils.sh
. "$CURRENT_DIR/utils.sh"
# shellcheck source=src/separators.sh
. "$CURRENT_DIR/separators.sh"
# shellcheck source=src/cache.sh
. "$CURRENT_DIR/cache.sh"

# =============================================================================
# Arguments
# =============================================================================
PLUGIN_NAME="${1:-}"
# Args 2-4: separator templates (unused - rebuilt with dynamic colors)
DEFAULT_ACCENT_COLOR="${5:-}"
DEFAULT_ACCENT_COLOR_ICON="${6:-}"
PLUGIN_ICON="${7:-}"
IS_LAST="${8:-0}"
WHITE_COLOR="${9:-}"
BG_HIGHLIGHT="${10:-}"
RIGHT_SEPARATOR="${11:-}"
TRANSPARENT="${12:-false}"
RIGHT_SEPARATOR_INVERSE="${13:-}"
PALETTE_SERIALIZED="${14:-}"

# =============================================================================
# Helper: Extract color from serialized palette
# =============================================================================
get_palette_color() {
    local color_name="$1"
    local default="$2"
    local result
    result=$(echo "$PALETTE_SERIALIZED" | grep -o "${color_name}=[^;]*" | cut -d'=' -f2)
    printf '%s' "${result:-$default}"
}

# =============================================================================
# Main Logic
# =============================================================================
PLUGIN_SCRIPT="${CURRENT_DIR}/plugin/${PLUGIN_NAME}.sh"

[[ ! -f "$PLUGIN_SCRIPT" ]] && exit 0

# Execute plugin and get content
content=$("$PLUGIN_SCRIPT" 2>/dev/null) || content=""
[[ -z "$content" ]] && exit 0

# Extract numeric value for threshold checks
numeric_value="${content//[!0-9]/}"

# Check display condition
display_threshold=$(get_tmux_option "@theme_plugin_${PLUGIN_NAME}_display_threshold" "")
display_condition=$(get_tmux_option "@theme_plugin_${PLUGIN_NAME}_display_condition" "always")

if [[ -n "$display_threshold" ]] && [[ "$display_condition" != "always" ]]; then
    check_display_threshold "$numeric_value" "$display_threshold" "$display_condition" || exit 0
fi

# =============================================================================
# Determine Colors (static or threshold-based)
# =============================================================================
final_accent_color="$DEFAULT_ACCENT_COLOR"
final_accent_color_icon="$DEFAULT_ACCENT_COLOR_ICON"
final_icon="$PLUGIN_ICON"

# Check if plugin wants to skip low threshold (generic mechanism)
# Plugins can set this by creating a cache file: <plugin>_skip_low_threshold.cache with value "1"
skip_low_threshold="0"
skip_cache_file="${CACHE_DIR:-$HOME/.cache/tmux-tokyo-night}/${PLUGIN_NAME}_skip_low_threshold.cache"
if [[ -f "$skip_cache_file" ]]; then
    skip_low_threshold=$(\cat "$skip_cache_file" 2>/dev/null | head -1)
fi

# Check if plugin has overridden the icon (generic mechanism)
# Plugins can set this by creating a cache file: <plugin>_icon_override.cache
icon_override_file="${CACHE_DIR:-$HOME/.cache/tmux-tokyo-night}/${PLUGIN_NAME}_icon_override.cache"
if [[ -f "$icon_override_file" ]]; then
    icon_override=$(\cat "$icon_override_file" 2>/dev/null | head -1)
    [[ -n "$icon_override" ]] && final_icon="$icon_override"
fi

# Check for plugin-specific low threshold (simple two-state: normal/low)
# Only apply if plugin hasn't requested to skip
low_threshold=$(get_tmux_option "@theme_plugin_${PLUGIN_NAME}_low_threshold" "")

if [[ "$skip_low_threshold" != "1" ]] && [[ -n "$low_threshold" ]] && [[ -n "$numeric_value" ]] && [[ "$numeric_value" -le "$low_threshold" ]]; then
    # Get low state configuration
    low_accent_color=$(get_tmux_option "@theme_plugin_${PLUGIN_NAME}_low_accent_color" "")
    low_accent_color_icon=$(get_tmux_option "@theme_plugin_${PLUGIN_NAME}_low_accent_color_icon" "")
    icon_low=$(get_tmux_option "@theme_plugin_${PLUGIN_NAME}_icon_low" "")
    
    # Resolve palette colors for low state
    if [[ -n "$PALETTE_SERIALIZED" ]]; then
        [[ -n "$low_accent_color" ]] && final_accent_color=$(get_palette_color "$low_accent_color" "$DEFAULT_ACCENT_COLOR")
        [[ -n "$low_accent_color_icon" ]] && final_accent_color_icon=$(get_palette_color "$low_accent_color_icon" "$DEFAULT_ACCENT_COLOR_ICON")
    fi
    
    # Update icon if low icon is configured
    [[ -n "$icon_low" ]] && final_icon="$icon_low"
fi

threshold_mode=$(get_tmux_option "@theme_plugin_${PLUGIN_NAME}_threshold_mode" "")

if [[ -n "$threshold_mode" ]] && [[ -n "$numeric_value" ]]; then
    # Get threshold configuration
    critical_threshold=$(get_tmux_option "@theme_plugin_${PLUGIN_NAME}_critical_threshold" "10")
    warning_threshold=$(get_tmux_option "@theme_plugin_${PLUGIN_NAME}_warning_threshold" "30")
    
    critical_color=$(get_tmux_option "@theme_plugin_${PLUGIN_NAME}_critical_color" "red")
    critical_color_icon=$(get_tmux_option "@theme_plugin_${PLUGIN_NAME}_critical_color_icon" "red1")
    warning_color=$(get_tmux_option "@theme_plugin_${PLUGIN_NAME}_warning_color" "yellow")
    warning_color_icon=$(get_tmux_option "@theme_plugin_${PLUGIN_NAME}_warning_color_icon" "orange")
    normal_color=$(get_tmux_option "@theme_plugin_${PLUGIN_NAME}_normal_color" "green")
    normal_color_icon=$(get_tmux_option "@theme_plugin_${PLUGIN_NAME}_normal_color_icon" "green1")
    
    # Select color based on mode
    if [[ "$threshold_mode" == "descending" ]]; then
        selected_color=$(get_threshold_color_descending "$numeric_value" \
            "$critical_threshold" "$warning_threshold" \
            "$critical_color" "$warning_color" "$normal_color")
        selected_color_icon=$(get_threshold_color_descending "$numeric_value" \
            "$critical_threshold" "$warning_threshold" \
            "$critical_color_icon" "$warning_color_icon" "$normal_color_icon")
    else
        selected_color=$(get_threshold_color_ascending "$numeric_value" \
            "$critical_threshold" "$warning_threshold" \
            "$normal_color" "$warning_color" "$critical_color")
        selected_color_icon=$(get_threshold_color_ascending "$numeric_value" \
            "$critical_threshold" "$warning_threshold" \
            "$normal_color_icon" "$warning_color_icon" "$critical_color_icon")
    fi
    
    # Resolve palette colors
    if [[ -n "$PALETTE_SERIALIZED" ]]; then
        final_accent_color=$(get_palette_color "$selected_color" "$DEFAULT_ACCENT_COLOR")
        final_accent_color_icon=$(get_palette_color "$selected_color_icon" "$DEFAULT_ACCENT_COLOR_ICON")
    fi
fi

# =============================================================================
# Build Output
# =============================================================================
sep_icon_start=$(build_separator_icon_start "$final_accent_color_icon" "$BG_HIGHLIGHT" "$RIGHT_SEPARATOR" "$TRANSPARENT")
sep_icon_end=$(build_separator_icon_end "$final_accent_color" "$final_accent_color_icon" "$RIGHT_SEPARATOR")
sep_end=$(build_separator_end "$final_accent_color" "$BG_HIGHLIGHT" "$RIGHT_SEPARATOR" "$TRANSPARENT" "$RIGHT_SEPARATOR_INVERSE")

icon_output=$(build_icon_section "$sep_icon_start" "$sep_icon_end" "$WHITE_COLOR" "$final_accent_color_icon" "$final_icon")
content_output=$(build_content_section "$WHITE_COLOR" "$final_accent_color" "$content" "$IS_LAST")

printf '%s' "$(build_plugin_segment "$icon_output" "$content_output" "$sep_end" "$IS_LAST")"
