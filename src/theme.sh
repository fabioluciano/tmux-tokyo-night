#!/usr/bin/env bash
set -euo pipefail

export LC_ALL=en_US.UTF-8

CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=src/utils.sh
. "$CURRENT_DIR/utils.sh"

theme_variation=$(get_tmux_option "@theme_variation" "night")
theme_disable_plugins=$(get_tmux_option "@theme_disable_plugins" 0)
theme_bar_layout=$(get_tmux_option "@theme_bar_layout" "single")

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
if ! tmux set-option -g pane-border-style "#{?pane_synchronized,fg=$border_style_active_pane,fg=$border_style_inactive_pane}" &>/dev/null; then
  tmux set-option -g pane-border-style "fg=$border_style_active_pane,fg=$border_style_inactive_pane"
fi

### Status bar lines setup
if [ "$theme_bar_layout" = "double" ]; then
	tmux set-option -g status 2
else
	tmux set-option -g status on
	# Reset status-format to default for single mode
	tmux set-option -g status-format[0] "#[align=left range=left #{E:status-left-style}]#[push-default]#{T;=/#{status-left-length}:status-left}#[pop-default]#[norange default]#[list=on align=#{status-justify}]#[list=left-marker]<#[list=right-marker]>#[list=on]#{W:#[range=window|#{window_index} #{E:window-status-style}#{?#{&&:#{window_last_flag},#{!=:#{E:window-status-last-style},default}}, #{E:window-status-last-style},}#{?#{&&:#{window_bell_flag},#{!=:#{E:window-status-bell-style},default}}, #{E:window-status-bell-style},#{?#{&&:#{||:#{window_activity_flag},#{window_silence_flag}},#{!=:#{E:window-status-activity-style},default}}, #{E:window-status-activity-style},}}]#[push-default]#{T:window-status-format}#[pop-default]#[norange default]#{?window_end_flag,,#{window-status-separator}},#[range=window|#{window_index} list=focus #{?#{!=:#{E:window-status-current-style},default},#{E:window-status-current-style},#{E:window-status-style}}#{?#{&&:#{window_last_flag},#{!=:#{E:window-status-last-style},default}}, #{E:window-status-last-style},}#{?#{&&:#{window_bell_flag},#{!=:#{E:window-status-bell-style},default}}, #{E:window-status-bell-style},#{?#{&&:#{||:#{window_activity_flag},#{window_silence_flag}},#{!=:#{E:window-status-activity-style},default}}, #{E:window-status-activity-style},}}]#[push-default]#{T:window-status-current-format}#[pop-default]#[norange default]#{?window_end_flag,,#{window-status-separator}}}#[nolist align=right range=right #{E:status-right-style}]#[push-default]#{T;=/#{status-right-length}:status-right}#[pop-default]#[norange default]"
	tmux set-option -gu status-format[1] 2>/dev/null || true
fi

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

			# For every plugin, turn accent_color and accent_color_icon into
			# the colors from the palette
			accent_color="${PALLETE[$accent_color]}"
			accent_color_icon="${PALLETE[$accent_color_icon]}"

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

			# Conditional plugins (git, docker) - only show when they have content
			if [ "$plugin" == "git" ] || [ "$plugin" == "docker" ]; then
				plugin_output_string="#(${CURRENT_DIR}/conditional_plugin.sh \"${plugin}\" \"${separator_icon_start}\" \"${separator_icon_end}\" \"${separator_end}\" \"${accent_color}\" \"${accent_color_icon}\" \"${plugin_icon}\" \"${is_last_plugin}\" \"${PALLETE[white]}\")"
				tmux set-option -ga status-right "$plugin_output_string"
				continue
			fi

			plugin_output_string=""

			# For datetime, we embed the content at load time (uses tmux strftime)
			# For other plugins, we use #() to execute dynamically
			if [ "$plugin" == "datetime" ]; then
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

			tmux set-option -ga status-right "$plugin_output_string"
		fi
	done
fi

# For double layout, set up the two status lines
if [ "$theme_bar_layout" = "double" ]; then
	# Get current status-left and status-right
	current_status_left=$(tmux show-option -gqv status-left)
	current_status_right=$(tmux show-option -gqv status-right)
	
	# Line 0: Session + Windows (no plugins on right)
	tmux set-option -g status-format[0] "#[align=left range=left #{E:status-left-style}]#[push-default]#{T;=/#{status-left-length}:status-left}#[pop-default]#[norange default]#[list=on align=#{status-justify}]#[list=left-marker]<#[list=right-marker]>#[list=on]#{W:#[range=window|#{window_index} #{E:window-status-style}#{?#{&&:#{window_last_flag},#{!=:#{E:window-status-last-style},default}}, #{E:window-status-last-style},}#{?#{&&:#{window_bell_flag},#{!=:#{E:window-status-bell-style},default}}, #{E:window-status-bell-style},#{?#{&&:#{||:#{window_activity_flag},#{window_silence_flag}},#{!=:#{E:window-status-activity-style},default}}, #{E:window-status-activity-style},}}]#[push-default]#{T:window-status-format}#[pop-default]#[norange default]#{?window_end_flag,,#{window-status-separator}},#[range=window|#{window_index} list=focus #{?#{!=:#{E:window-status-current-style},default},#{E:window-status-current-style},#{E:window-status-style}}#{?#{&&:#{window_last_flag},#{!=:#{E:window-status-last-style},default}}, #{E:window-status-last-style},}#{?#{&&:#{window_bell_flag},#{!=:#{E:window-status-bell-style},default}}, #{E:window-status-bell-style},#{?#{&&:#{||:#{window_activity_flag},#{window_silence_flag}},#{!=:#{E:window-status-activity-style},default}}, #{E:window-status-activity-style},}}]#[push-default]#{T:window-status-current-format}#[pop-default]#[norange default]#{?window_end_flag,,#{window-status-separator}}}#[nolist align=right range=right #{E:status-right-style}]#[push-default]#[pop-default]#[norange default]"
	
	# Line 1: Plugins only (right aligned)
	tmux set-option -g status-format[1] "#[align=right range=right #{E:status-right-style}]#[push-default]#{T;=/#{status-right-length}:status-right}#[pop-default]#[norange default]"
fi

tmux set-window-option -g window-status-separator ''
