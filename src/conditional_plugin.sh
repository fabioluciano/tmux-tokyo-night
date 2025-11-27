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

PLUGIN_SCRIPT="${CURRENT_DIR}/plugin/${PLUGIN_NAME}.sh"

[[ ! -f "$PLUGIN_SCRIPT" ]] && exit 0

# Execute plugin and get content
content=$("$PLUGIN_SCRIPT" 2>/dev/null) || content=""

# Only render if there's content
if [[ -n "$content" ]]; then
    # Build icon section
    icon_output="${SEP_ICON_START}#[fg=${WHITE_COLOR},bg=${ACCENT_COLOR_ICON}]${PLUGIN_ICON}${SEP_ICON_END}"
    
    # Build content section
    content_output="#[fg=${WHITE_COLOR},bg=${ACCENT_COLOR}] ${content}#[none]"
    
    # Combine with or without separator
    if [[ "$IS_LAST" != "1" ]]; then
        printf '%s' "${icon_output}${content_output} ${SEP_END}"
    else
        printf '%s' "${icon_output}${content_output} "
    fi
fi
