#!/usr/bin/env bash
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$ROOT_DIR/../utils.sh"

#
# shellcheck disable=SC2005
plugin_playerctl_icon=$(get_tmux_option "@theme_plugin_playerctl_icon" "󰝚 ")
plugin_playerctl_accent_color=$(get_tmux_option "@theme_plugin_playerctl_accent_color" "blue7")
plugin_playerctl_accent_color_icon=$(get_tmux_option "@theme_plugin_playerctl_accent_color_icon" "blue0")

plugin_playerctl_format_string=$(get_tmux_option "@theme_plugin_playerctl_format_string" "{{artist}} - {{title}}")

export plugin_playerctl_icon plugin_playerctl_accent_color plugin_playerctl_accent_color_icon

function load_plugin() {
	if ! command -v playerctl &>/dev/null; then
		exit 1
	fi

	if [[ $(playerctl status) == "Playing" ]]; then
		playerctl=$(playerctl metadata --format "$plugin_playerctl_format_string")
		echo "${playerctl}"
	else
		echo "Not Playing"
	fi
}

load_plugin
