#!/usr/bin/env bash
# =============================================================================
# Conditional Plugin Wrapper
# Renders a plugin segment only if the plugin returns content
# Used for plugins like git, docker, homebrew, yay that may have nothing to show
#
# Usage: conditional_plugin.sh <plugin_name> <accent_color> <accent_color_icon>
#        <plugin_icon> <white_color> <bg_highlight> <transparent>
#        <prev_plugin_accent> <plugins_after>
# =============================================================================

CURRENT_DIR="$(cd "$(dirname "$0")" && pwd)"

# shellcheck source=src/utils.sh
. "$CURRENT_DIR/utils.sh"
# shellcheck source=src/separators.sh
. "$CURRENT_DIR/separators.sh"

# Read separator directly from tmux (Unicode chars don't pass well as arguments)
RIGHT_SEPARATOR=$(get_tmux_option "@theme_right_separator" $'\ue0b2')
RIGHT_SEPARATOR_INVERSE=$(get_tmux_option "@theme_transparent_right_separator_inverse" $'\ue0d6')

# =============================================================================
# Arguments
# =============================================================================
PLUGIN_NAME="${1:-}"
ACCENT_COLOR="${2:-}"
ACCENT_COLOR_ICON="${3:-}"
PLUGIN_ICON="${4:-}"
WHITE_COLOR="${5:-}"
BG_HIGHLIGHT="${6:-}"
TRANSPARENT="${7:-false}"
PREV_PLUGIN_ACCENT="${8:-}"
PLUGINS_AFTER="${9:-}"

# =============================================================================
# Helper Functions
# =============================================================================

# Check if any plugin in the list has content (for dynamic last detection)
any_plugin_has_content() {
    local plugins_list="$1"
    [[ -z "$plugins_list" ]] && return 1
    
    IFS=',' read -ra plugins_array <<< "$plugins_list"
    for p in "${plugins_array[@]}"; do
        local script="${CURRENT_DIR}/plugin/${p}.sh"
        [[ ! -f "$script" ]] && continue
        local output
        output=$("$script" 2>/dev/null) || output=""
        [[ -n "$output" ]] && return 0
    done
    return 1
}

# =============================================================================
# Main Logic
# =============================================================================
PLUGIN_SCRIPT="${CURRENT_DIR}/plugin/${PLUGIN_NAME}.sh"

[[ ! -f "$PLUGIN_SCRIPT" ]] && exit 0

# Execute plugin and get content
content=$("$PLUGIN_SCRIPT" 2>/dev/null) || content=""

# Only render if there's content
if [[ -n "$content" ]]; then
    # Dynamically determine if this is the last plugin with content
    if [[ -z "$PLUGINS_AFTER" ]] || ! any_plugin_has_content "$PLUGINS_AFTER"; then
        IS_LAST=1
    else
        IS_LAST=0
    fi
    
    # Build separators
    SEP_ICON_START=$(build_separator_icon_start "$ACCENT_COLOR_ICON" "$BG_HIGHLIGHT" "$RIGHT_SEPARATOR" "$TRANSPARENT")
    SEP_ICON_END=$(build_separator_icon_end "$ACCENT_COLOR" "$ACCENT_COLOR_ICON" "$RIGHT_SEPARATOR")
    SEP_END=$(build_separator_end "$ACCENT_COLOR" "$BG_HIGHLIGHT" "$RIGHT_SEPARATOR" "$TRANSPARENT" "$RIGHT_SEPARATOR_INVERSE")
    
    # Build icon section using centralized function
    base_icon_output=$(build_icon_section "$SEP_ICON_START" "$SEP_ICON_END" "$WHITE_COLOR" "$ACCENT_COLOR_ICON" "$PLUGIN_ICON")
    
    # Add entry separator if needed
    if [[ -n "$PREV_PLUGIN_ACCENT" ]]; then
        # Previous plugin was "last" (didn't add separator_end)
        entry_sep=$(build_entry_separator "$PREV_PLUGIN_ACCENT" "$BG_HIGHLIGHT" "$RIGHT_SEPARATOR" "$TRANSPARENT" "$RIGHT_SEPARATOR_INVERSE")
        icon_output="${entry_sep}${base_icon_output}"
    else
        icon_output="$base_icon_output"
    fi
    
    # Build content and final output
    content_output=$(build_content_section "$WHITE_COLOR" "$ACCENT_COLOR" "$content" "$IS_LAST")
    
    if [[ "$IS_LAST" == "1" ]]; then
        printf '%s' "$(build_plugin_segment "$icon_output" "$content_output" "" "$IS_LAST")"
    else
        printf '%s' "$(build_plugin_segment "$icon_output" "$content_output" "$SEP_END" "$IS_LAST")"
    fi
fi
