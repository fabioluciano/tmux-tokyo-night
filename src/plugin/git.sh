#!/usr/bin/env bash
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$ROOT_DIR/../utils.sh"

# shellcheck disable=SC2005
plugin_git_icon=$(get_tmux_option "@theme_plugin_git_icon" " ")
plugin_git_accent_color=$(get_tmux_option "@theme_plugin_git_accent_color" "blue7")
plugin_git_accent_color_icon=$(get_tmux_option "@theme_plugin_git_accent_color_icon" "blue0")

export plugin_git_icon plugin_git_accent_color plugin_git_accent_color_icon

function load_plugin() {
	echo "test"
}
load_plugin
