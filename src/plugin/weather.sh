#!/usr/bin/env bash
#
# shellcheck disable=SC2005
plugin_weather_icon=$(get_tmux_option "@theme_plugin_weather_icon" "")
plugin_weather_accent_color=$(get_tmux_option "@theme_plugin_weather_accent_color" "blue7")
plugin_weather_accent_color_icon=$(get_tmux_option "@theme_plugin_weather_accent_color_icon" "blue0")

# https://man7.org/linux/man-pages/man1/date.1.html
plugin_weather_format=$(get_tmux_option "@theme_plugin_weather_format" "%c")

function load_plugin() {
  echo "${plugin_weather_format}"
} 

export plugin_weather_icon plugin_weather_accent_color plugin_weather_accent_color_icon
