#!/usr/bin/env bash

plugin_datetime_icon=$(get_tmux_option "@theme_plugin_datetime_icon" "")
plugin_datetime_accent_color=$(get_tmux_option "@theme_plugin_datetime_accent_color" "green")
plugin_datetime_accent_color_icon=$(get_tmux_option "@theme_plugin_datetime_accent_color_icon" "othergreen")

# https://man7.org/linux/man-pages/man1/date.1.html
plugin_datetime_format=$(get_tmux_option "@theme_plugin_datetime_format" "%F")

function load_plugin() {
  echo "$(date +"${plugin_datetime_format}")"
} 
