#!/usr/bin/env bash
# =============================================================================
# Plugin: datetime
# Description: Display current date and time
# Dependencies: None (uses tmux's built-in strftime)
# =============================================================================

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck source=src/utils.sh
. "$ROOT_DIR/../utils.sh"

# =============================================================================
# Plugin Configuration
# =============================================================================

# shellcheck disable=SC2034
plugin_datetime_icon=$(get_tmux_option "@theme_plugin_datetime_icon" " ")
# shellcheck disable=SC2034
plugin_datetime_accent_color=$(get_tmux_option "@theme_plugin_datetime_accent_color" "blue7")
# shellcheck disable=SC2034
plugin_datetime_accent_color_icon=$(get_tmux_option "@theme_plugin_datetime_accent_color_icon" "blue0")

# Date format - see https://man7.org/linux/man-pages/man1/date.1.html
plugin_datetime_format=$(get_tmux_option "@theme_plugin_datetime_format" "%D %H:%M:%S")

export plugin_datetime_icon plugin_datetime_accent_color plugin_datetime_accent_color_icon

# =============================================================================
# Main Plugin Logic
# =============================================================================

load_plugin() {
    # Return format string - tmux will interpret strftime placeholders
    printf '%s' "$plugin_datetime_format"
}

# Only run if executed directly (not sourced)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    load_plugin
fi
