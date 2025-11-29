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

# Serialize palette for threshold_plugin.sh
serialize_palette() {
    local result=""
    for key in "${!PALLETE[@]}"; do
        result+="${key}=${PALLETE[$key]};"
    done
    printf '%s' "$result"
}
PALETTE_SERIALIZED=$(serialize_palette)

# List of conditional plugins (may not render)
CONDITIONAL_PLUGINS="git docker homebrew yay"

# Function to check if a plugin is conditional
is_conditional_plugin() {
    local plugin="$1"
    [[ " $CONDITIONAL_PLUGINS " == *" $plugin "* ]]
}

# Check if there are any conditional plugins after a given plugin index
has_conditional_plugins_after() {
    local current_idx="$1"
    local total="${#plugins[@]}"
    
    for ((i=current_idx+1; i<total; i++)); do
        if is_conditional_plugin "${plugins[$i]}"; then
            return 0  # true - there are conditional plugins after
        fi
    done
    return 1  # false - no conditional plugins after
}

# Check if the NEXT plugin (immediately after) is conditional
next_plugin_is_conditional() {
    local current_idx="$1"
    local total="${#plugins[@]}"
    local next_idx=$((current_idx + 1))
    
    if [ "$next_idx" -lt "$total" ]; then
        is_conditional_plugin "${plugins[$next_idx]}"
        return $?
    fi
    return 1  # false - no next plugin
}

# Check if there are any STATIC (non-conditional) plugins after a given plugin index
has_static_plugins_after() {
    local current_idx="$1"
    local total="${#plugins[@]}"
    
    for ((i=current_idx+1; i<total; i++)); do
        if ! is_conditional_plugin "${plugins[$i]}"; then
            return 0  # true - there is a static plugin after
        fi
    done
    return 1  # false - no static plugins after (only conditional or none)
}

# Check if plugins array is empty before proceeding
if [ "$theme_disable_plugins" -ne 1 ]; then
	last_plugin="${plugins[-1]}"
	is_last_plugin=0
	plugin_index=0
	prev_plugin_accent_color=""  # Track previous plugin's accent color
	prev_was_last=0  # Track if previous plugin was treated as "last" (no separator_end)
	prev_plugin_accent_color=""  # Track previous plugin's accent color for conditional plugins

	for plugin in "${plugins[@]}"; do

		if [ ! -f "${CURRENT_DIR}/plugin/${plugin}.sh" ]; then
			tmux set-option -ga status-right "${plugin}"
		else
			# A plugin is "last" (no separator_end) if:
			# 1. It's the actual last plugin in the list AND not conditional, OR
			# 2. There are only conditional plugins after it (they handle their own entry separator)
			#
			# When followed by conditional plugins, the static plugin does NOT add separator_end.
			# The conditional plugin will add its own entry separator if it renders.
			if [ "$plugin" == "$last_plugin" ] && ! is_conditional_plugin "$plugin"; then
				is_last_plugin=1
			elif ! has_static_plugins_after "$plugin_index"; then
				# Only conditional plugins (or nothing) after - don't add separator
				is_last_plugin=1
			else
				is_last_plugin=0
			fi

			plugin_script_path="${CURRENT_DIR}/plugin/${plugin}.sh"
			# Source plugin once to get config variables and use load_plugin function
			# shellcheck source=src/plugin/datetime.sh
			. "$plugin_script_path"
			# Get execution string from sourced load_plugin function (avoids double execution)
			plugin_execution_string="$(load_plugin)"

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

			separator_end="#[fg=${PALLETE[bg_highlight]},bg=${accent_color}]${right_separator}#[bg=${PALLETE[bg_highlight]}]"
			separator_icon_start="#[fg=${accent_color_icon},bg=${PALLETE[bg_highlight]}]${right_separator}#[none]"
			separator_icon_end="#[fg=${accent_color},bg=${accent_color_icon}]${right_separator}#[none]"
			if [ "$transparent" = "true" ]; then
				separator_icon_start="#[fg=${accent_color_icon},bg=default]${right_separator}#[none]"
				separator_icon_end="#[fg=${accent_color},bg=${accent_color_icon}]${right_separator}#[none]"
				separator_end="#[fg=${accent_color},bg=default]${right_separator_inverse}#[bg=default]"
			else
				separator_icon_start="#[fg=${accent_color_icon},bg=${PALLETE[bg_highlight]}]${right_separator}#[none]"
				separator_icon_end="#[fg=${accent_color},bg=${accent_color_icon}]${right_separator}#[none]"
				separator_end="#[fg=${PALLETE[bg_highlight]},bg=${accent_color}]${right_separator}#[bg=${PALLETE[bg_highlight]}]"
			fi

			# Conditional plugins (git, docker, homebrew, yay) - only show when they have content
			# Pass is_last=1 only if this is the actual last plugin in the list
			# Only pass prev_plugin_accent if previous plugin didn't add separator_end
			if [ "$plugin" == "git" ] || [ "$plugin" == "docker" ] || [ "$plugin" == "homebrew" ] || [ "$plugin" == "yay" ]; then
				conditional_is_last=0
				if [ "$plugin" == "$last_plugin" ]; then
					conditional_is_last=1
				fi
				# Only pass prev_accent if previous plugin didn't add separator (prev was "last")
				prev_accent_to_pass=""
				if [ "$prev_was_last" == "1" ]; then
					prev_accent_to_pass="$prev_plugin_accent_color"
				fi
				plugin_output_string="#(${CURRENT_DIR}/conditional_plugin.sh \"${plugin}\" \"${separator_icon_start}\" \"${separator_icon_end}\" \"${separator_end}\" \"${accent_color}\" \"${accent_color_icon}\" \"${plugin_icon}\" \"${conditional_is_last}\" \"${PALLETE[white]}\" \"${PALLETE[bg_highlight]}\" \"${right_separator}\" \"${transparent}\" \"${right_separator_inverse:-}\" \"${prev_accent_to_pass}\")"
				tmux set-option -ga status-right "$plugin_output_string"
				prev_plugin_accent_color="$accent_color"
				prev_was_last="$conditional_is_last"
				plugin_index=$((plugin_index + 1))
				continue
			fi

			# Check if plugin has threshold mode or display threshold configured
			# These plugins use the threshold_plugin.sh wrapper for dynamic colors and/or conditional display
			threshold_mode=$(get_tmux_option "@theme_plugin_${plugin}_threshold_mode" "")
			display_condition=$(get_tmux_option "@theme_plugin_${plugin}_display_condition" "always")
			
			if [ -n "$threshold_mode" ] || [ "$display_condition" != "always" ]; then
				plugin_output_string="#(${CURRENT_DIR}/threshold_plugin.sh \"${plugin}\" \"${separator_icon_start}\" \"${separator_icon_end}\" \"${separator_end}\" \"${accent_color}\" \"${accent_color_icon}\" \"${plugin_icon}\" \"${is_last_plugin}\" \"${PALLETE[white]}\" \"${PALLETE[bg_highlight]}\" \"${right_separator}\" \"${transparent}\" \"${right_separator_inverse:-}\" \"${PALETTE_SERIALIZED}\")"
				tmux set-option -ga status-right "$plugin_output_string"
				prev_plugin_accent_color="$accent_color"
				prev_was_last="$is_last_plugin"
				plugin_index=$((plugin_index + 1))
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
			prev_plugin_accent_color="$accent_color"
			prev_was_last="$is_last_plugin"
		fi
		plugin_index=$((plugin_index + 1))
	done
fi

# For double layout, set up the two status lines
if [ "$theme_bar_layout" = "double" ]; then
	# Line 0: Session + Windows (no plugins on right)
	tmux set-option -g status-format[0] "#[align=left range=left #{E:status-left-style}]#[push-default]#{T;=/#{status-left-length}:status-left}#[pop-default]#[norange default]#[list=on align=#{status-justify}]#[list=left-marker]<#[list=right-marker]>#[list=on]#{W:#[range=window|#{window_index} #{E:window-status-style}#{?#{&&:#{window_last_flag},#{!=:#{E:window-status-last-style},default}}, #{E:window-status-last-style},}#{?#{&&:#{window_bell_flag},#{!=:#{E:window-status-bell-style},default}}, #{E:window-status-bell-style},#{?#{&&:#{||:#{window_activity_flag},#{window_silence_flag}},#{!=:#{E:window-status-activity-style},default}}, #{E:window-status-activity-style},}}]#[push-default]#{T:window-status-format}#[pop-default]#[norange default]#{?window_end_flag,,#{window-status-separator}},#[range=window|#{window_index} list=focus #{?#{!=:#{E:window-status-current-style},default},#{E:window-status-current-style},#{E:window-status-style}}#{?#{&&:#{window_last_flag},#{!=:#{E:window-status-last-style},default}}, #{E:window-status-last-style},}#{?#{&&:#{window_bell_flag},#{!=:#{E:window-status-bell-style},default}}, #{E:window-status-bell-style},#{?#{&&:#{||:#{window_activity_flag},#{window_silence_flag}},#{!=:#{E:window-status-activity-style},default}}, #{E:window-status-activity-style},}}]#[push-default]#{T:window-status-current-format}#[pop-default]#[norange default]#{?window_end_flag,,#{window-status-separator}}}#[nolist align=right range=right #{E:status-right-style}]#[push-default]#[pop-default]#[norange default]"
	
	# Line 1: Plugins only (right aligned)
	tmux set-option -g status-format[1] "#[align=right range=right #{E:status-right-style}]#[push-default]#{T;=/#{status-right-length}:status-right}#[pop-default]#[norange default]"
fi

tmux set-window-option -g window-status-separator ''
