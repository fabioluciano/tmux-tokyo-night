#!/usr/bin/env bash

# https://man7.org/linux/man-pages/man1/date.1.html
plugin_datetime_format=$(get_tmux_option "@theme_plugin_datetime_format" "%F")

function load_plugin() {
  local accent_color="${1:-blue2}"

  local separator_start="#[fg=${PALLETE[$accent_color]},bg=${PALLETE[lesslessdark]}]${right_separator}#[none]"
  local separator_end="#[fg=${PALLETE[lesslessdark]},bg=${PALLETE[$accent_color]}]${right_separator}#[none]"
  local output_string="#[fg=${PALLETE[dark]},bg=${PALLETE[$accent_color]}] $(date +"${plugin_datetime_format}") "

  echo "${separator_start}${output_string}${separator_end}"
} 
