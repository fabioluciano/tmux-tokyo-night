#!/usr/bin/env bash
#
# shellcheck disable=SC2005
plugin_playerctl_icon=$(get_tmux_option "@theme_plugin_playerctl_icon" " ")
plugin_playerctl_accent_color=$(get_tmux_option "@theme_plugin_playerctl_accent_color" "blue7")
plugin_playerctl_accent_color_icon=$(get_tmux_option "@theme_plugin_playerctl_accent_color_icon" "blue0")

plugin_playerctl_format_string=$(get_tmux_option "@theme_plugin_playerctl_format_string" "{{artist}} - {{title}}")

function load_plugin() {
	playerctl=$(playerctl metadata --format "${plugin_playerctl_format_string}")

	echo "${playerctl}"
}

export plugin_playerctl_icon plugin_playerctl_accent_color plugin_playerctl_accent_color_icon
