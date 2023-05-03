#!/usr/bin/env bash

function load_plugin() {
  local accent_color="orange"

  local separator_start="#[fg=${PALLETE[$accent_color]},bg=${PALLETE[lesslessdark]}]${right_separator}#[none]"
  local separator_end="#[fg=${PALLETE[lesslessdark]},bg=${PALLETE[$accent_color]}]${right_separator}#[none]"
  local output_string="#[fg=${PALLETE[dark]},bg=${PALLETE[$accent_color]}] teste #[none]"

  echo "${separator_start}${output_string}${separator_end}"
} 
