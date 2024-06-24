#!/usr/bin/env bash
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$ROOT_DIR/../utils.sh"

# shellcheck disable=SC2005
plugin_weather_icon=$(get_tmux_option "@theme_plugin_weather_icon" " ")
plugin_weather_accent_color=$(get_tmux_option "@theme_plugin_weather_accent_color" "blue7")
plugin_weather_accent_color_icon=$(get_tmux_option "@theme_plugin_weather_accent_color_icon" "blue0")

export plugin_weather_icon plugin_weather_accent_color plugin_weather_accent_color_icon

plugin_weather_format_string=$(get_tmux_option "@theme_plugin_weather_format" "%t+H:%h")

function load_plugin() {
	if ! command -v jq &>/dev/null; then
		exit 1
	fi

	LOCATION=$(curl -s http://ip-api.com/json | jq -r '"\(.city), \(.country)"' 2>/dev/null)
	WEATHER=$(curl -sL wttr.in/${LOCATION// /%20}\?format="${plugin_weather_format_string}" 2>/dev/null)

	echo "${WEATHER}"
}

load_plugin
