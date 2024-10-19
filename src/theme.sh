#!/usr/bin/env bash
set -euxo pipefail

export LC_ALL=en_US.UTF-8

CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=src/utils.sh
. "$CURRENT_DIR/utils.sh"

theme_variation=$(get_tmux_option "@theme_variation" "night")
theme_disable_plugins=$(get_tmux_option "@theme_disable_plugins" 0)

# shellcheck source=src/palletes/night.sh
. "$CURRENT_DIR/palletes/$theme_variation.sh"

### Load Options
border_style_active_pane=$(get_tmux_option "@theme_active_pane_border_style" "${PALLETE['dark5']}")
border_style_inactive_pane=$(get_tmux_option "@theme_inactive_pane_border_style" "${PALLETE[bg_highlight]}")
right_separator=$(get_tmux_option "@theme_right_separator" "")
transparent=$(get_tmux_option "@theme_transparent_status_bar" "false")

if [ "$transparent" = "true" ]; then
	right_separator_inverse=$(get_tmux_option "@theme_transparent_right_separator_inverse" "")
fi

window_with_activity_style=$(get_tmux_option "@theme_window_with_activity_style" "italics")
window_status_bell_style=$(get_tmux_option "@theme_status_bell_style" "bold")

IFS=',' read -r -a plugins <<<"$(get_tmux_option "@theme_plugins" "datetime,weather")"

tmux set-option -g status-left-length 100
tmux set-option -g status-right-length 100

tmux set-window-option -g window-status-activity-style "$window_with_activity_style"
tmux set-window-option -g window-status-bell-style "${window_status_bell_style}"

# message styling
tmux set-option -g message-style "bg=${PALLETE[red]},fg=${PALLETE[bg_dark]}"

# status bar
status_bar_bg=${PALLETE[bg_highlight]}
if [ "$transparent" = "true" ]; then
	status_bar_bg="default"
fi
tmux set-option -g status-style "bg=${status_bar_bg},fg=${PALLETE[white]}"

# border color
tmux set-option -g pane-active-border-style "fg=$border_style_active_pane"
tmux set-option -g pane-border-style "#{?pane_synchronized,fg=$border_style_active_pane,fg=$border_style_inactive_pane}"

### Left side
tmux set-option -g status-left "$(generate_left_side_string)"

### Windows list
tmux set-window-option -g window-status-format "$(generate_inactive_window_string)"
tmux set-window-option -g window-status-current-format "$(generate_active_window_string)"

### Right side
tmux set-option -g status-right ""

# Check if plugins array is empty before proceeding
if [ "$theme_disable_plugins" -ne 1 ]; then
	last_plugin="${plugins[-1]}"
	is_last_plugin=0

	for plugin in "${plugins[@]}"; do

		if [ ! -f "${CURRENT_DIR}/plugin/${plugin}.sh" ]; then
			tmux set-option -ga status-right "${plugin}"
		else
			if [ "$plugin" == "$last_plugin" ]; then
				is_last_plugin=1
			fi

			plugin_script_path="${CURRENT_DIR}/plugin/${plugin}.sh"
			plugin_execution_string="$(${plugin_script_path})"
			# shellcheck source=src/plugin/datetime.sh
			. "$plugin_script_path"

			icon_var="plugin_${plugin}_icon"
			accent_color_var="plugin_${plugin}_accent_color"
			accent_color_icon_var="plugin_${plugin}_accent_color_icon"

			plugin_icon="${!icon_var}"
			accent_color="${!accent_color_var}"
			accent_color_icon="${!accent_color_icon_var}"

			# For every plugin except battery, turn accent_color and accent_color_icon into
			# the colors from the palette. The battery plugin uses placeholders so it can
			# change the color based on battery level
			if [ "$plugin" != "battery" ]; then
				accent_color="${PALLETE[$accent_color]}"
				accent_color_icon="${PALLETE[$accent_color_icon]}"
			fi

			separator_end="#[fg=${PALLETE[bg_highlight]},bg=${accent_color}]${right_separator}#[none]"
			separator_icon_start="#[fg=${accent_color_icon},bg=${PALLETE[bg_highlight]}]${right_separator}#[none]"
			separator_icon_end="#[fg=${accent_color},bg=${accent_color_icon}]${right_separator}#[none]"
			if [ "$transparent" = "true" ]; then
				separator_icon_start="#[fg=${accent_color_icon},bg=default]${right_separator}#[none]"
				separator_icon_end="#[fg=${accent_color},bg=${accent_color_icon}]${right_separator}#[none]"
				separator_end="#[fg=${accent_color},bg=default]${right_separator_inverse}#[none]"
			else
				separator_icon_start="#[fg=${accent_color_icon},bg=${PALLETE[bg_highlight]}]${right_separator}#[none]"
				separator_icon_end="#[fg=${accent_color},bg=${accent_color_icon}]${right_separator}#[none]"
				separator_end="#[fg=${PALLETE[bg_highlight]},bg=${accent_color}]${right_separator}#[none]"
			fi

			plugin_output_string=""

			# For datetime and battery, we run the plugin to get the content
			# For battery, the content is actually a template that will be replaced when
			# running the script later
			if [ "$plugin" == "datetime" ] || [ "$plugin" == "battery" ]; then
				plugin_output="#[fg=${PALLETE[white]},bg=${accent_color}]${plugin_execution_string}#[none]"
			else
				plugin_output="#[fg=${PALLETE[white]},bg=${accent_color}]#($plugin_script_path)#[none]"
			fi

			plugin_icon_output="${separator_icon_start}#[fg=${PALLETE[white]},bg=${accent_color_icon}]${plugin_icon}${separator_icon_end}"

			if [ ! $is_last_plugin -eq 1 ] && [ "${#plugins[@]}" -gt 1 ]; then
				plugin_output_string="${plugin_icon_output}${plugin_output} ${separator_end}"
			else
				plugin_output_string="${plugin_icon_output}${plugin_output} "
			fi

			# For the battery plugin, we pass $plugin_output_string as an argument to the script so 
			# we can dynamically change the icon and accent colors
			if [ "$plugin" == "battery" ]; then
				plugin_output_string="#($plugin_script_path \"$plugin_output_string\")"
			fi

			tmux set-option -ga status-right "$plugin_output_string"
		fi
	done
fi

tmux set-window-option -g window-status-separator ''
