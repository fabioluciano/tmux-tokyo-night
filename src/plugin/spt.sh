#!/usr/bin/env bash
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$ROOT_DIR/../utils.sh"

#
# shellcheck disable=SC2005
plugin_spt_icon=$(get_tmux_option "@theme_plugin_spt_icon" "󰝚 ")
plugin_spt_accent_color=$(get_tmux_option "@theme_plugin_spt_accent_color" "blue7")
plugin_spt_accent_color_icon=$(get_tmux_option "@theme_plugin_spt_accent_color_icon" "blue0")

plugin_spt_format_string=$(get_tmux_option "@theme_plugin_spt_format_string" "%a - %t")

export plugin_spt_icon plugin_spt_accent_color plugin_spt_accent_color_icon

function load_plugin() {
	if ! command -v spt &>/dev/null; then
		exit 1
	fi

	if spt playback --status >/dev/null; then
		spt=$(spt playback --format "$plugin_spt_format_string")
		echo "${spt}"
	else
		echo "Not Playing"
	fi
}

load_plugin
