#!/usr/bin/env bash
# =============================================================================
# Conditional Plugin Wrapper
# Renders a plugin segment only if the plugin returns content
# Usage: conditional_plugin.sh <plugin_name> <separator_args...>
# =============================================================================

CURRENT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Arguments passed from theme.sh
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
PREV_PLUGIN_ACCENT="${14:-}"  # Previous plugin's accent color for entry transition

PLUGIN_SCRIPT="${CURRENT_DIR}/plugin/${PLUGIN_NAME}.sh"

[[ ! -f "$PLUGIN_SCRIPT" ]] && exit 0

# Execute plugin and get content
content=$("$PLUGIN_SCRIPT" 2>/dev/null) || content=""

# Only render if there's content
if [[ -n "$content" ]]; then
    # Build entry separator if needed - transition from previous plugin's accent color
    # When we add entry_sep, we need to build the icon section differently
    # because SEP_ICON_START already contains a separator glyph
    if [[ -n "$PREV_PLUGIN_ACCENT" ]]; then
        # We need entry separator - build full transition
        if [[ "$TRANSPARENT" == "true" ]]; then
            entry_sep="#[fg=${PREV_PLUGIN_ACCENT},bg=default]${RIGHT_SEPARATOR_INVERSE}#[bg=default]"
        else
            entry_sep="#[fg=${BG_HIGHLIGHT},bg=${PREV_PLUGIN_ACCENT}]${RIGHT_SEPARATOR}#[bg=${BG_HIGHLIGHT}]"
        fi
        # After entry_sep, continue with normal SEP_ICON_START
        icon_output="${entry_sep}${SEP_ICON_START}#[fg=${WHITE_COLOR},bg=${ACCENT_COLOR_ICON}]${PLUGIN_ICON}${SEP_ICON_END}"
    else
        # No entry separator needed - previous plugin added separator_end
        icon_output="${SEP_ICON_START}#[fg=${WHITE_COLOR},bg=${ACCENT_COLOR_ICON}]${PLUGIN_ICON}${SEP_ICON_END}"
    fi
    
    # Build content section
    content_output="#[fg=${WHITE_COLOR},bg=${ACCENT_COLOR}] ${content}#[none]"
    
    # Combine with or without trailing separator
    # Last plugin should NOT have any trailing separator
    if [[ "$IS_LAST" != "1" ]]; then
        printf '%s' "${icon_output}${content_output} ${SEP_END}"
    else
        printf '%s' "${icon_output}${content_output} "
    fi
fi
