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
# shellcheck disable=SC1090
. "$CURRENT_DIR/palletes/$theme_variation.sh"

### Load Options
border_style_active_pane=$(get_tmux_option "@theme_active_pane_border_style" "${PALLETE['dark5']}")
border_style_inactive_pane=$(get_tmux_option "@theme_inactive_pane_border_style" "${PALLETE[bg_highlight]}")
transparent=$(get_tmux_option "@theme_transparent_status_bar" "$THEME_DEFAULT_TRANSPARENT")

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
	# Note: status-format[0] will be updated after plugins are processed to set correct trailing background
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

# Serialize palette for passing to render_plugins.sh
serialize_palette() {
    local result=""
    for key in "${!PALLETE[@]}"; do
        result+="${key}=${PALLETE[$key]};"
    done
    printf '%s' "$result"
}

# List of conditional plugins (only show when they have content)
readonly CONDITIONAL_PLUGINS=" git docker homebrew yay spotify kubernetes playerctl spt "

# Get plugin type
# Types: conditional (only show if has content), static (always show)
# Note: Display conditions and color changes are handled by each plugin via plugin_get_display_info()
get_plugin_type() {
    local plugin="$1"
    
    # Check if it's a conditional plugin (only show when they have content)
    # Fast string match with pre-padded string
    [[ "$CONDITIONAL_PLUGINS" == *" $plugin "* ]] && printf 'conditional' && return
    
    # Default: always show (static)
    printf 'static'
}

# =============================================================================
# Plugin Rendering - Unified Approach
# =============================================================================

if [ "$theme_disable_plugins" -ne 1 ]; then
	PALETTE_SERIALIZED=$(serialize_palette)
	
	# Build unified plugin config for render_plugins.sh
	# Format: "name:accent:accent_icon:icon:type;..."
	plugin_configs=""
	
	for plugin in "${plugins[@]}"; do
		plugin_script_path="${CURRENT_DIR}/plugin/${plugin}.sh"
		
		# Skip non-existent plugins
		if [ ! -f "$plugin_script_path" ]; then
			continue
		fi
		
		# Source plugin to get its config variables
		# shellcheck source=/dev/null
		. "$plugin_script_path"
		
		# Check for keybindings function while plugin is already sourced
		if declare -f setup_keybindings &>/dev/null; then
			setup_keybindings
			unset -f setup_keybindings
		fi
		
		# Get plugin settings via indirect variable expansion
		icon_var="plugin_${plugin}_icon"
		accent_color_var="plugin_${plugin}_accent_color"
		accent_color_icon_var="plugin_${plugin}_accent_color_icon"
		
		plugin_icon="${!icon_var}"
		accent_color="${!accent_color_var}"
		accent_color_icon="${!accent_color_icon_var}"
		
		# Resolve palette colors
		accent_color="${PALLETE[$accent_color]}"
		accent_color_icon="${PALLETE[$accent_color_icon]}"
		
		# Get plugin type
		plugin_type=$(get_plugin_type "$plugin")
		
		# Handle datetime specially (uses tmux strftime)
		if [ "$plugin" == "datetime" ]; then
			plugin_type="datetime"
		fi
		
		# Add to config string
		[[ -n "$plugin_configs" ]] && plugin_configs+=";"
		plugin_configs+="${plugin}:${accent_color}:${accent_color_icon}:${plugin_icon}:${plugin_type}"
	done
	
	# Render all plugins via unified renderer
	if [ -n "$plugin_configs" ]; then
		plugin_output_string="#(RENDER_WHITE='${PALLETE[white]}' RENDER_BG_HIGHLIGHT='${PALLETE[bg_highlight]}' RENDER_TRANSPARENT='${transparent}' RENDER_PALETTE='${PALETTE_SERIALIZED}' ${CURRENT_DIR}/render_plugins.sh '${plugin_configs}')"
		tmux set-option -ga status-right "$plugin_output_string"
		
		# Set status-right-style to match last plugin's accent color (fills gap to edge)
		tmux set-option -g status-right-style "bg=${accent_color}"
		
		# Set status-format[0] for single layout with correct trailing background color
		if [ "$theme_bar_layout" != "double" ]; then
			tmux set-option -g status-format[0] "#[align=left range=left #{E:status-left-style}]#[push-default]#{T;=/#{status-left-length}:status-left}#[pop-default]#[norange default]#[list=on align=#{status-justify}]#[list=left-marker]<#[list=right-marker]>#[list=on]#{W:#[range=window|#{window_index} #{E:window-status-style}#{?#{&&:#{window_last_flag},#{!=:#{E:window-status-last-style},default}}, #{E:window-status-last-style},}#{?#{&&:#{window_bell_flag},#{!=:#{E:window-status-bell-style},default}}, #{E:window-status-bell-style},#{?#{&&:#{||:#{window_activity_flag},#{window_silence_flag}},#{!=:#{E:window-status-activity-style},default}}, #{E:window-status-activity-style},}}]#[push-default]#{T:window-status-format}#[pop-default]#[norange default]#{?window_end_flag,,#{window-status-separator}},#[range=window|#{window_index} list=focus #{?#{!=:#{E:window-status-current-style},default},#{E:window-status-current-style},#{E:window-status-style}}#{?#{&&:#{window_last_flag},#{!=:#{E:window-status-last-style},default}}, #{E:window-status-last-style},}#{?#{&&:#{window_bell_flag},#{!=:#{E:window-status-bell-style},default}}, #{E:window-status-bell-style},#{?#{&&:#{||:#{window_activity_flag},#{window_silence_flag}},#{!=:#{E:window-status-activity-style},default}}, #{E:window-status-activity-style},}}]#[push-default]#{T:window-status-current-format}#[pop-default]#[norange default]#{?window_end_flag,,#{window-status-separator}}}#[nolist align=right range=right #{E:status-right-style}]#[push-default]#{T;=/#{status-right-length}:status-right}#[pop-default]#[norange bg=${accent_color}]"
		fi
	fi
fi

# For double layout, set up the two status lines
if [ "$theme_bar_layout" = "double" ]; then
	tmux set-option -g status-format[0] "#[align=left range=left #{E:status-left-style}]#[push-default]#{T;=/#{status-left-length}:status-left}#[pop-default]#[norange default]#[list=on align=#{status-justify}]#[list=left-marker]<#[list=right-marker]>#[list=on]#{W:#[range=window|#{window_index} #{E:window-status-style}#{?#{&&:#{window_last_flag},#{!=:#{E:window-status-last-style},default}}, #{E:window-status-last-style},}#{?#{&&:#{window_bell_flag},#{!=:#{E:window-status-bell-style},default}}, #{E:window-status-bell-style},#{?#{&&:#{||:#{window_activity_flag},#{window_silence_flag}},#{!=:#{E:window-status-activity-style},default}}, #{E:window-status-activity-style},}}]#[push-default]#{T:window-status-format}#[pop-default]#[norange default]#{?window_end_flag,,#{window-status-separator}},#[range=window|#{window_index} list=focus #{?#{!=:#{E:window-status-current-style},default},#{E:window-status-current-style},#{E:window-status-style}}#{?#{&&:#{window_last_flag},#{!=:#{E:window-status-last-style},default}}, #{E:window-status-last-style},}#{?#{&&:#{window_bell_flag},#{!=:#{E:window-status-bell-style},default}}, #{E:window-status-bell-style},#{?#{&&:#{||:#{window_activity_flag},#{window_silence_flag}},#{!=:#{E:window-status-activity-style},default}}, #{E:window-status-activity-style},}}]#[push-default]#{T:window-status-current-format}#[pop-default]#[norange default]#{?window_end_flag,,#{window-status-separator}}}#[nolist align=right range=right #{E:status-right-style}]#[push-default]#[pop-default]#[norange default]"
	tmux set-option -g status-format[1] "#[align=right range=right #{E:status-right-style}]#[push-default]#{T;=/#{status-right-length}:status-right}#[pop-default]#[norange default]"
fi

tmux set-window-option -g window-status-separator ''

# =============================================================================
# Theme Helper Keybindings
# =============================================================================

# Helper popup keybindings
theme_help_key=$(get_tmux_option "@theme_helper_key" "$THEME_DEFAULT_HELPER_KEY")
theme_help_width=$(get_tmux_option "@theme_helper_width" "$THEME_DEFAULT_HELPER_WIDTH")
theme_help_height=$(get_tmux_option "@theme_helper_height" "$THEME_DEFAULT_HELPER_HEIGHT")
theme_keybindings_key=$(get_tmux_option "@theme_keybindings_key" "$THEME_DEFAULT_KEYBINDINGS_KEY")
theme_keybindings_width=$(get_tmux_option "@theme_keybindings_width" "$THEME_DEFAULT_KEYBINDINGS_WIDTH")
theme_keybindings_height=$(get_tmux_option "@theme_keybindings_height" "$THEME_DEFAULT_KEYBINDINGS_HEIGHT")

# Options reference popup (prefix + ?)
if [[ -n "$theme_help_key" ]]; then
    tmux bind-key "$theme_help_key" display-popup -E -w "$theme_help_width" -h "$theme_help_height" \
        "${CURRENT_DIR}/helpers/options_viewer.sh"
fi

# Keybindings viewer popup (prefix + B)
if [[ -n "$theme_keybindings_key" ]]; then
    tmux bind-key "$theme_keybindings_key" display-popup -E -w "$theme_keybindings_width" -h "$theme_keybindings_height" \
        "${CURRENT_DIR}/helpers/keybindings_viewer.sh"
fi