#!/usr/bin/env bash
# =============================================================================
# Conditional Plugin Wrapper
# Renders a plugin segment only if the plugin returns content
# Used for plugins like git, docker, homebrew, yay that may have nothing to show
#
# Usage: conditional_plugin.sh <plugin_name> <separator_args...>
# =============================================================================

CURRENT_DIR="$(cd "$(dirname "$0")" && pwd)"

# shellcheck source=src/separators.sh
. "$CURRENT_DIR/separators.sh"

# =============================================================================
# Arguments
# =============================================================================
PLUGIN_NAME="${1:-}"
SEP_ICON_START="${2:-}"
SEP_ICON_END="${3:-}"
SEP_END="${4:-}"
ACCENT_COLOR="${5:-}"
ACCENT_COLOR_ICON="${6:-}"
PLUGIN_ICON="${7:-}"
IS_LAST="${8:-0}"
WHITE_COLOR="${9:-}"
BG_HIGHLIGHT="${10:-}"
RIGHT_SEPARATOR="${11:-}"
TRANSPARENT="${12:-false}"
RIGHT_SEPARATOR_INVERSE="${13:-}"
PREV_PLUGIN_ACCENT="${14:-}"

# =============================================================================
# Main Logic
# =============================================================================
PLUGIN_SCRIPT="${CURRENT_DIR}/plugin/${PLUGIN_NAME}.sh"

[[ ! -f "$PLUGIN_SCRIPT" ]] && exit 0

# Execute plugin and get content
content=$("$PLUGIN_SCRIPT" 2>/dev/null) || content=""

# Only render if there's content
if [[ -n "$content" ]]; then
    # Build entry separator if previous plugin didn't add one
    if [[ -n "$PREV_PLUGIN_ACCENT" ]]; then
        entry_sep=$(build_entry_separator "$PREV_PLUGIN_ACCENT" "$BG_HIGHLIGHT" "$RIGHT_SEPARATOR" "$TRANSPARENT" "$RIGHT_SEPARATOR_INVERSE")
        icon_output="${entry_sep}${SEP_ICON_START}#[fg=${WHITE_COLOR},bg=${ACCENT_COLOR_ICON}]${PLUGIN_ICON}${SEP_ICON_END}"
    else
        icon_output="${SEP_ICON_START}#[fg=${WHITE_COLOR},bg=${ACCENT_COLOR_ICON}]${PLUGIN_ICON}${SEP_ICON_END}"
    fi
    
    # Build content and final output
    content_output=$(build_content_section "$WHITE_COLOR" "$ACCENT_COLOR" "$content")
    printf '%s' "$(build_plugin_segment "$icon_output" "$content_output" "$SEP_END" "$IS_LAST")"
fi
