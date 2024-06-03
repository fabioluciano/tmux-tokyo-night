#!/usr/bin/env bash
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$ROOT_DIR/../utils.sh"

# shellcheck disable=SC2005
plugin_yay_icon=$(get_tmux_option "@theme_plugin_yay_icon" " ")
plugin_yay_accent_color=$(get_tmux_option "@theme_plugin_yay_accent_color" "blue7")
plugin_yay_accent_color_icon=$(get_tmux_option "@theme_plugin_yay_accent_color_icon" "blue0")

export plugin_yay_icon plugin_yay_accent_color plugin_yay_accent_color_icon

function load_plugin() {
	if ! command -v yay &>/dev/null; then
		exit 1
	fi

	outdated_packages=$(yay -Qu || true)
	outdated_packages_count=$(echo "${outdated_packages}" | wc -l | xargs)
	if [[ "${outdated_packages_count}" -gt 1 ]]; then
		echo "$outdated_packages_count outdated packages"
	else
		echo "All updated"
	fi
}

load_plugin
