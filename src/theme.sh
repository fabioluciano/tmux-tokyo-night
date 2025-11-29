#!/usr/bin/env bash
# =============================================================================
# tmux-tokyo-night Theme Configuration
# Main entry point for theme initialization and plugin rendering
# =============================================================================
set -euo pipefail

export LC_ALL=en_US.UTF-8

CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# =============================================================================
# Source Dependencies
# =============================================================================
# shellcheck source=src/defaults.sh
. "$CURRENT_DIR/defaults.sh"
# shellcheck source=src/utils.sh
. "$CURRENT_DIR/utils.sh"
# shellcheck source=src/separators.sh
. "$CURRENT_DIR/separators.sh"

# =============================================================================
# Theme Configuration Options
# =============================================================================
theme_variation=$(get_tmux_option "@theme_variation" "$THEME_DEFAULT_VARIATION")
theme_disable_plugins=$(get_tmux_option "@theme_disable_plugins" "$THEME_DEFAULT_DISABLE_PLUGINS")
theme_bar_layout=$(get_tmux_option "@theme_bar_layout" "$THEME_DEFAULT_BAR_LAYOUT")

# shellcheck source=src/palletes/night.sh
. "$CURRENT_DIR/palletes/$theme_variation.sh"

### Load Options
border_style_active_pane=$(get_tmux_option "@theme_active_pane_border_style" "${PALLETE['dark5']}")
border_style_inactive_pane=$(get_tmux_option "@theme_inactive_pane_border_style" "${PALLETE[bg_highlight]}")
right_separator=$(get_tmux_option "@theme_right_separator" "$THEME_DEFAULT_RIGHT_SEPARATOR")
transparent=$(get_tmux_option "@theme_transparent_status_bar" "$THEME_DEFAULT_TRANSPARENT")

if [ "$transparent" = "true" ]; then
	right_separator_inverse=$(get_tmux_option "@theme_transparent_right_separator_inverse" "$THEME_DEFAULT_RIGHT_SEPARATOR_INVERSE")
fi

window_with_activity_style=$(get_tmux_option "@theme_window_with_activity_style" "$THEME_DEFAULT_WINDOW_WITH_ACTIVITY_STYLE")
window_status_bell_style=$(get_tmux_option "@theme_status_bell_style" "$THEME_DEFAULT_STATUS_BELL_STYLE")

IFS=',' read -r -a plugins <<<"$(get_tmux_option "@theme_plugins" "$THEME_DEFAULT_PLUGINS")"

# Status bar length limits (configurable)
status_left_length=$(get_tmux_option "@theme_status_left_length" "$THEME_DEFAULT_STATUS_LEFT_LENGTH")
status_right_length=$(get_tmux_option "@theme_status_right_length" "$THEME_DEFAULT_STATUS_RIGHT_LENGTH")

tmux set-option -g status-left-length "$status_left_length"
tmux set-option -g status-right-length "$status_right_length"

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

# =============================================================================
# Plugin Helper Functions
# =============================================================================

# Serialize palette for passing to external scripts (threshold_plugin.sh)
serialize_palette() {
    local result=""
    for key in "${!PALLETE[@]}"; do
        result+="${key}=${PALLETE[$key]};"
    done
    printf '%s' "$result"
}

# List of conditional plugins that may not render (only show when they have content)
readonly CONDITIONAL_PLUGINS="git docker homebrew yay spotify kubernetes"

# Check if a plugin is conditional (may not render)
is_conditional_plugin() {
    local plugin="$1"
    [[ " $CONDITIONAL_PLUGINS " == *" $plugin "* ]]
}

# Check if there are any static (non-conditional) plugins after a given index
has_static_plugins_after() {
    local current_idx="$1"
    local total="${#plugins[@]}"
    
    for ((i=current_idx+1; i<total; i++)); do
        if ! is_conditional_plugin "${plugins[$i]}"; then
            return 0
        fi
    done
    return 1
}

# =============================================================================
# Plugin Rendering
# =============================================================================

if [ "$theme_disable_plugins" -ne 1 ]; then
	# Pre-calculate values used in the loop
	PALETTE_SERIALIZED=$(serialize_palette)
	last_plugin="${plugins[-1]}"
	
	# State tracking variables
	plugin_index=0
	prev_plugin_accent_color=""
	prev_was_last=0

	for plugin in "${plugins[@]}"; do
		plugin_script_path="${CURRENT_DIR}/plugin/${plugin}.sh"
		
		# Skip non-existent plugins (display plugin name as-is)
		if [ ! -f "$plugin_script_path" ]; then
			tmux set-option -ga status-right "${plugin}"
			plugin_index=$((plugin_index + 1))
			continue
		fi
		
		# Determine if this plugin should add a trailing separator
		# A plugin is "last" (no separator_end) if:
		#   - It's the actual last AND not conditional, OR
		#   - Only conditional plugins follow (they handle their own entry separator)
		if [ "$plugin" == "$last_plugin" ] && ! is_conditional_plugin "$plugin"; then
			is_last_plugin=1
		elif ! has_static_plugins_after "$plugin_index"; then
			is_last_plugin=1
		else
			is_last_plugin=0
		fi
		
		# -----------------------------------------------------------------
		# Load Plugin Configuration
		# -----------------------------------------------------------------
		# shellcheck source=src/plugin/datetime.sh
		. "$plugin_script_path"
		plugin_execution_string="$(load_plugin)"

		# Get plugin-specific settings via indirect variable expansion
		icon_var="plugin_${plugin}_icon"
		accent_color_var="plugin_${plugin}_accent_color"
		accent_color_icon_var="plugin_${plugin}_accent_color_icon"
		
		plugin_icon="${!icon_var}"
		accent_color="${!accent_color_var}"
		accent_color_icon="${!accent_color_icon_var}"

		# Resolve palette colors
		accent_color="${PALLETE[$accent_color]}"
		accent_color_icon="${PALLETE[$accent_color_icon]}"

		# -----------------------------------------------------------------
		# Render Plugin Based on Type
		# -----------------------------------------------------------------
		
		# CONDITIONAL PLUGINS: Only render when they have content
		if is_conditional_plugin "$plugin"; then
			prev_accent_to_pass=$([ "$prev_was_last" == "1" ] && echo "$prev_plugin_accent_color" || echo "")
			
			# Build list of plugins that come after this one (for dynamic last detection)
			plugins_after=""
			for ((i=plugin_index+1; i<${#plugins[@]}; i++)); do
				[[ -n "$plugins_after" ]] && plugins_after+=","
				plugins_after+="${plugins[$i]}"
			done
			
			plugin_output_string="#(${CURRENT_DIR}/conditional_plugin.sh \"${plugin}\" \"${accent_color}\" \"${accent_color_icon}\" \"${plugin_icon}\" \"${PALLETE[white]}\" \"${PALLETE[bg_highlight]}\" \"${transparent}\" \"${prev_accent_to_pass}\" \"${plugins_after}\")"
			tmux set-option -ga status-right "$plugin_output_string"
			
			prev_plugin_accent_color="$accent_color"
			prev_was_last=$([ "$plugin" == "$last_plugin" ] && echo 1 || echo 0)
		
		# THRESHOLD PLUGINS: Dynamic colors based on value
		elif [ -n "$(get_tmux_option "@theme_plugin_${plugin}_threshold_mode" "")" ] || \
		     [ "$(get_tmux_option "@theme_plugin_${plugin}_display_condition" "always")" != "always" ] || \
		     [ -n "$(get_tmux_option "@theme_plugin_${plugin}_low_threshold" "")" ]; then
			
			# Set plugin-specific defaults for battery
			if [ "$plugin" == "battery" ]; then
				[ -z "$(get_tmux_option "@theme_plugin_battery_low_threshold" "")" ] && \
					tmux set-option -gq "@theme_plugin_battery_low_threshold" "$PLUGIN_BATTERY_LOW_THRESHOLD"
				[ -z "$(get_tmux_option "@theme_plugin_battery_icon_low" "")" ] && \
					tmux set-option -gq "@theme_plugin_battery_icon_low" "$PLUGIN_BATTERY_ICON_LOW"
				[ -z "$(get_tmux_option "@theme_plugin_battery_low_accent_color" "")" ] && \
					tmux set-option -gq "@theme_plugin_battery_low_accent_color" "$PLUGIN_BATTERY_LOW_ACCENT_COLOR"
				[ -z "$(get_tmux_option "@theme_plugin_battery_low_accent_color_icon" "")" ] && \
					tmux set-option -gq "@theme_plugin_battery_low_accent_color_icon" "$PLUGIN_BATTERY_LOW_ACCENT_COLOR_ICON"
			fi
			
			# Build separators for threshold plugins
			separator_icon_start=$(build_separator_icon_start "$accent_color_icon" "${PALLETE[bg_highlight]}" "$right_separator" "$transparent")
			separator_icon_end=$(build_separator_icon_end "$accent_color" "$accent_color_icon" "$right_separator")
			separator_end=$(build_separator_end "$accent_color" "${PALLETE[bg_highlight]}" "$right_separator" "$transparent" "${right_separator_inverse:-}")
			
			plugin_output_string="#(${CURRENT_DIR}/threshold_plugin.sh \"${plugin}\" \"${separator_icon_start}\" \"${separator_icon_end}\" \"${separator_end}\" \"${accent_color}\" \"${accent_color_icon}\" \"${plugin_icon}\" \"${is_last_plugin}\" \"${PALLETE[white]}\" \"${PALLETE[bg_highlight]}\" \"${right_separator}\" \"${transparent}\" \"${right_separator_inverse:-}\" \"${PALETTE_SERIALIZED}\")"
			tmux set-option -ga status-right "$plugin_output_string"
			
			prev_plugin_accent_color="$accent_color"
			prev_was_last="$is_last_plugin"
		
		# STATIC PLUGINS: Standard rendering
		else
			# Build list of plugins that come after this one
			plugins_after=""
			for ((i=plugin_index+1; i<${#plugins[@]}; i++)); do
				[[ -n "$plugins_after" ]] && plugins_after+=","
				plugins_after+="${plugins[$i]}"
			done
			
			# Check if we need dynamic last detection (only conditional plugins follow)
			needs_dynamic_check=0
			if [ "$is_last_plugin" == "1" ] && [ -n "$plugins_after" ]; then
				# We're marked as "last" but there are plugins after us
				# This means only conditional plugins follow - use dynamic check
				needs_dynamic_check=1
			fi
			
			if [ "$needs_dynamic_check" == "1" ]; then
				# Use static_plugin.sh for dynamic last detection
				plugin_output_string="#(${CURRENT_DIR}/static_plugin.sh \"${plugin}\" \"${accent_color}\" \"${accent_color_icon}\" \"${plugin_icon}\" \"${PALLETE[white]}\" \"${PALLETE[bg_highlight]}\" \"${transparent}\" \"${plugins_after}\")"
				tmux set-option -ga status-right "$plugin_output_string"
				
				# static_plugin.sh dynamically adds separator_end when needed,
				# so next plugin should NOT add entry_separator
				prev_plugin_accent_color="$accent_color"
				prev_was_last="0"
			else
				# Build separators for static plugins
				separator_icon_start=$(build_separator_icon_start "$accent_color_icon" "${PALLETE[bg_highlight]}" "$right_separator" "$transparent")
				separator_icon_end=$(build_separator_icon_end "$accent_color" "$accent_color_icon" "$right_separator")
				separator_end=$(build_separator_end "$accent_color" "${PALLETE[bg_highlight]}" "$right_separator" "$transparent" "${right_separator_inverse:-}")
				
				# datetime uses tmux strftime, others execute dynamically
				if [ "$plugin" == "datetime" ]; then
					content_output="$(build_content_section "${PALLETE[white]}" "$accent_color" "${plugin_execution_string# }" "$is_last_plugin")"
				else
					if [ "$is_last_plugin" == "1" ]; then
						content_output="#[fg=${PALLETE[white]},bg=${accent_color}] #($plugin_script_path)#[none]"
					else
						content_output="#[fg=${PALLETE[white]},bg=${accent_color}] #($plugin_script_path) #[none]"
					fi
				fi
				
				icon_output="$(build_icon_section "$separator_icon_start" "$separator_icon_end" "${PALLETE[white]}" "$accent_color_icon" "$plugin_icon")"
				plugin_output_string="$(build_plugin_segment "$icon_output" "$content_output" "$separator_end" "$is_last_plugin")"
				
				tmux set-option -ga status-right "$plugin_output_string"
				
				prev_plugin_accent_color="$accent_color"
				prev_was_last="$is_last_plugin"
			fi
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
