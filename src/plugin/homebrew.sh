#!/usr/bin/env bash
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$ROOT_DIR/../utils.sh"

# shellcheck disable=SC2005
plugin_homebrew_icon=$(get_tmux_option "@theme_plugin_homebrew_icon" " ")
plugin_homebrew_accent_color=$(get_tmux_option "@theme_plugin_homebrew_accent_color" "blue7")
plugin_homebrew_accent_color_icon=$(get_tmux_option "@theme_plugin_homebrew_accent_color_icon" "blue0")

plugin_homebrew_additional_options=$(get_tmux_option "@theme_plugin_homebrew_additional_options" "--greedy")

export plugin_homebrew_icon plugin_homebrew_accent_color plugin_homebrew_accent_color_icon

function load_plugin() {
	if ! command -v brew &>/dev/null; then
		exit 1
	fi

	outdated_packages=$(brew outdated "${plugin_homebrew_additional_options}" || true)
	outdated_packages_count=$(echo "${outdated_packages}" | wc -l | xargs)
	if [[ "${outdated_packages_count}" -gt 1 ]]; then
		echo "$outdated_packages_count outdated packages"
	else
		echo "All updated"
	fi
}

load_plugin
