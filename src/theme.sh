#!/usr/bin/env bash
# =============================================================================
# PowerKit Theme Architecture
# Modular window and status bar management system
# =============================================================================
set -euo pipefail
export LC_ALL=en_US.UTF-8

CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# =============================================================================
# Source Dependencies
# =============================================================================
. "$CURRENT_DIR/defaults.sh"
. "$CURRENT_DIR/utils.sh"
. "$CURRENT_DIR/cache.sh"

# =============================================================================
# WINDOW INDEX SYSTEM
# Manages window number display and styling
# =============================================================================

# Get window index colors based on window state
get_window_index_colors() {
    local window_state="$1"  # "active" or "inactive"
    
    if [[ "$window_state" == "active" ]]; then
        local bg_color_option=$(get_tmux_option "@powerkit_active_window_number_bg" "$POWERKIT_DEFAULT_ACTIVE_WINDOW_NUMBER_BG")
        local bg_color=$(get_powerkit_color "$bg_color_option")
        echo "bg=$bg_color"
    else
        local bg_color_option=$(get_tmux_option "@powerkit_inactive_window_number_bg" "$POWERKIT_DEFAULT_INACTIVE_WINDOW_NUMBER_BG")
        local bg_color=$(get_powerkit_color "$bg_color_option")
        echo "bg=$bg_color"
    fi
}

# Create window index segment
create_window_index_segment() {
    local window_state="$1"  # "active" or "inactive"
    local index_colors=$(get_window_index_colors "$window_state")
    local text_color=$(get_powerkit_color 'text')
    
    if [[ "$window_state" == "active" ]]; then
        echo "#[${index_colors},fg=${text_color},bold]#I"
    else
        echo "#[${index_colors},fg=${text_color}]#I"
    fi
}

# =============================================================================
# WINDOW CONTENT SYSTEM  
# Manages window content area (icons + title)
# =============================================================================

# Get window content colors based on window state
get_window_content_colors() {
    local window_state="$1"  # "active" or "inactive"
    
    if [[ "$window_state" == "active" ]]; then
        local bg_color_option=$(get_tmux_option "@powerkit_active_window_content_bg" "$POWERKIT_DEFAULT_ACTIVE_WINDOW_CONTENT_BG")
        local bg_color=$(get_powerkit_color "$bg_color_option")
        echo "bg=$bg_color"
    else
        local bg_color=$(get_powerkit_color 'border')
        echo "bg=$bg_color"
    fi
}

# Get window icon based on state
get_window_icon() {
    local window_state="$1"  # "active" or "inactive"
    
    if [[ "$window_state" == "active" ]]; then
        echo "$(get_tmux_option "@powerkit_active_window_icon" "$POWERKIT_DEFAULT_ACTIVE_WINDOW_ICON")"
    else
        echo "$(get_tmux_option "@powerkit_inactive_window_icon" "$POWERKIT_DEFAULT_INACTIVE_WINDOW_ICON")"
    fi
}

# Get window title format
get_window_title() {
    local window_state="$1"  # "active" or "inactive"
    
    if [[ "$window_state" == "active" ]]; then
        echo "$(get_tmux_option "@powerkit_active_window_title" "$POWERKIT_DEFAULT_ACTIVE_WINDOW_TITLE")"
    else
        echo "$(get_tmux_option "@powerkit_inactive_window_title" "$POWERKIT_DEFAULT_INACTIVE_WINDOW_TITLE")"
    fi
}

# Create window content segment
create_window_content_segment() {
    local window_state="$1"  # "active" or "inactive"
    local content_colors=$(get_window_content_colors "$window_state")
    local text_color=$(get_powerkit_color 'text')
    local window_icon=$(get_window_icon "$window_state")
    local window_title=$(get_window_title "$window_state")
    local zoomed_icon=$(get_tmux_option "@powerkit_zoomed_window_icon" "$POWERKIT_DEFAULT_ZOOMED_WINDOW_ICON")
    
    if [[ "$window_state" == "active" ]]; then
        local pane_sync_icon=$(get_tmux_option "@powerkit_pane_synchronized_icon" "$POWERKIT_DEFAULT_PANE_SYNCHRONIZED_ICON")
        echo "#[${content_colors},fg=${text_color},bold] #{?window_zoomed_flag,$zoomed_icon,$window_icon} ${window_title}#{?pane_synchronized,$pane_sync_icon,}"
    else
        echo "#[${content_colors},fg=${text_color}] #{?window_zoomed_flag,$zoomed_icon,$window_icon} ${window_title}"
    fi
}

# =============================================================================
# SEPARATOR SYSTEM
# Manages transitions between window segments and status areas
# =============================================================================

# Get separator character
get_separator_char() {
    echo "$(get_tmux_option "@powerkit_left_separator" "$POWERKIT_DEFAULT_LEFT_SEPARATOR")"
}

# Calculate previous window background for separator transition
get_previous_window_background() {
    local current_window_state="$1"  # "active" or "inactive"
    local separator_color
    
    # Session colors (for first window)
    local session_success=$(get_powerkit_color 'success')
    local session_warning=$(get_powerkit_color 'warning')
    
    # Window content colors
    local active_content_bg_option=$(get_tmux_option "@powerkit_active_window_content_bg" "$POWERKIT_DEFAULT_ACTIVE_WINDOW_CONTENT_BG")
    local active_content_bg=$(get_powerkit_color "$active_content_bg_option")
    local inactive_content_bg=$(get_powerkit_color 'border')
    
    if [[ "$current_window_state" == "active" ]]; then
        # For active window: previous window is always inactive (or session for first)
        separator_color="#{?#{==:#{window_index},1},#{?client_prefix,$session_warning,$session_success},$inactive_content_bg}"
    else
        # For inactive window: check if previous window is active
        separator_color="#{?#{==:#{e|-:#{window_index},1},0},#{?client_prefix,$session_warning,$session_success},#{?#{==:#{e|-:#{window_index},1},#{active_window_index}},$active_content_bg,$inactive_content_bg}}"
    fi
    
    echo "$separator_color"
}

# Create index-to-content separator (between window number and content)
create_index_content_separator() {
    local window_state="$1"  # "active" or "inactive"
    local separator_char=$(get_separator_char)
    local index_colors=$(get_window_index_colors "$window_state")
    local content_colors=$(get_window_content_colors "$window_state")
    
    # Extract background colors for transition
    local index_bg=$(echo "$index_colors" | sed 's/bg=//')
    local content_bg=$(echo "$content_colors" | sed 's/bg=//')
    
    echo "#[bg=${content_bg},fg=${index_bg}]${separator_char}"
}

# Create window-to-window separator (between different windows)
create_window_separator() {
    local current_window_state="$1"  # "active" or "inactive"
    local separator_char=$(get_separator_char)
    local previous_bg=$(get_previous_window_background "$current_window_state")
    local current_index_colors=$(get_window_index_colors "$current_window_state")
    local current_index_bg=$(echo "$current_index_colors" | sed 's/bg=//')
    
    echo "#[bg=${current_index_bg},fg=${previous_bg}]${separator_char}"
}

# Create final separator (end of window list to status bar)
create_final_separator() {
    local separator_char=$(get_separator_char)
    local status_bg=$(get_powerkit_color 'surface')
    
    # Get window content background colors for last window detection
    local active_content_bg_option=$(get_tmux_option "@powerkit_active_window_content_bg" "$POWERKIT_DEFAULT_ACTIVE_WINDOW_CONTENT_BG")
    local active_content_bg=$(get_powerkit_color "$active_content_bg_option")
    local inactive_content_bg=$(get_powerkit_color 'border')
    
    # Use color of the last window (active if last window is active, inactive otherwise)
    echo "#{?#{==:#{session_windows},#{active_window_index}},#[fg=${active_content_bg}],#[fg=${inactive_content_bg}]}#[bg=${status_bg}]${separator_char}"
}

# =============================================================================
# WINDOW ASSEMBLY SYSTEM
# Combines all segments into complete window formats
# =============================================================================

# Create complete window format for active window
create_active_window_format() {
    local window_separator=$(create_window_separator "active")
    local index_segment=$(create_window_index_segment "active")
    local index_content_sep=$(create_index_content_separator "active")
    local content_segment=$(create_window_content_segment "active")
    
    echo "${window_separator}${index_segment}${index_content_sep}${content_segment}"
}

# Create complete window format for inactive window  
create_inactive_window_format() {
    local window_separator=$(create_window_separator "inactive")
    local index_segment=$(create_window_index_segment "inactive")
    local index_content_sep=$(create_index_content_separator "inactive")
    local content_segment=$(create_window_content_segment "inactive")
    
    echo "${window_separator}${index_segment}${index_content_sep}${content_segment}"
}

# =============================================================================
# STATUS BAR SYSTEM
# Manages left side, right side, and overall status bar formatting  
# =============================================================================

# Create session segment (left side of status bar)
create_session_segment() {
    local session_icon=$(get_tmux_option "@powerkit_session_icon" "$POWERKIT_DEFAULT_SESSION_ICON")
    local separator_char=$(get_separator_char)
    local text_color=$(get_powerkit_color 'surface')
    local warning_bg=$(get_powerkit_color 'warning')
    local success_bg=$(get_powerkit_color 'success')
    local transparent=$(get_tmux_option "@powerkit_transparent_status_bar" "false")
    
    # Auto-detect OS icon if needed
    if [[ "$session_icon" == "auto" ]]; then
        session_icon=$(get_os_icon)
    fi
    
    # Handle transparency
    local separator_end
    if [[ "$transparent" == "true" ]]; then
        separator_end="#[bg=default]#{?client_prefix,#[fg=${warning_bg}],#[fg=${success_bg}]}${separator_char}#[none]"
    else
        separator_end="#{?client_prefix,#[fg=${warning_bg}],#[fg=${success_bg}]}${separator_char}#[none]"
    fi
    
    echo "#[fg=${text_color},bold]#{?client_prefix,#[bg=${warning_bg}],#[bg=${success_bg}]}${session_icon} #S${separator_end}"
}

# Build status left format
build_status_left_format() {
    printf '#[align=left range=left #{E:status-left-style}]#[push-default]#{T;=/#{status-left-length}:status-left}#[pop-default]#[norange default]'
}

# Build status right format  
build_status_right_format() {
    local resolved_accent_color="$1"
    printf '#[nolist align=right range=right #{E:status-right-style}]#[push-default]#{T;=/#{status-right-length}:status-right}#[pop-default]#[norange bg=%s]' "$resolved_accent_color"
}

# Build window list format
build_window_list_format() {
    printf '#[list=on align=#{status-justify}]#[list=left-marker]<#[list=right-marker]>#[list=on]'
}

# Build tmux native window format (using our custom formats)
build_tmux_window_format() {
    local window_conditions='#{?#{&&:#{window_last_flag},#{!=:#{E:window-status-last-style},default}}, #{E:window-status-last-style},}'
    window_conditions+='#{?#{&&:#{window_bell_flag},#{!=:#{E:window-status-bell-style},default}}, #{E:window-status-bell-style},'
    window_conditions+='#{?#{&&:#{||:#{window_activity_flag},#{window_silence_flag}},#{!=:#{E:window-status-activity-style},default}}, #{E:window-status-activity-style},}}'
    
    printf '#{W:#[range=window|#{window_index} #{E:window-status-style}%s]#[push-default]#{T:window-status-format}#[pop-default]#[norange default]#{?window_end_flag,,#{window-status-separator}},#[range=window|#{window_index} list=focus #{?#{!=:#{E:window-status-current-style},default},#{E:window-status-current-style},#{E:window-status-style}}%s]#[push-default]#{T:window-status-current-format}#[pop-default]#[norange default]#{?window_end_flag,,#{window-status-separator}}}' "$window_conditions" "$window_conditions"
}

# =============================================================================
# PLUGIN SYSTEM INTEGRATION
# Manages plugin loading and status bar integration
# =============================================================================

# Get plugins list for single layout
get_plugins_list() {
    local plugins=("$@")
    local plugin_configs=""
    
    # Build plugin config string for render_plugins.sh
    for plugin in "${plugins[@]}"; do
        [[ -z "$plugin" ]] && continue
        
        # Check for plugin keybindings setup
        local plugin_script="${CURRENT_DIR}/plugin/${plugin}.sh"
        if [[ -f "$plugin_script" ]]; then
            # Source plugin and check for keybindings function
            # shellcheck source=/dev/null
            if . "$plugin_script" 2>/dev/null && declare -f setup_keybindings &>/dev/null; then
                setup_keybindings
                unset -f setup_keybindings
            fi
        fi
        
        # Parse plugin format: name or name:accent:accent_icon:icon:type
        if [[ "$plugin" == *":"* ]]; then
            plugin_configs+="$plugin;"
        else
            # Get plugin type from the plugin itself
            local plugin_type="static"
            local plugin_script="${CURRENT_DIR}/plugin/${plugin}.sh"
            if [[ -f "$plugin_script" ]]; then
                # Source plugin and call plugin_get_type function
                # shellcheck source=/dev/null
                if . "$plugin_script" 2>/dev/null && declare -f plugin_get_type &>/dev/null; then
                    plugin_type=$(plugin_get_type)
                    unset -f plugin_get_type
                fi
            fi
            
            # Get plugin colors from defaults
            local plugin_upper="${plugin^^}"
            plugin_upper="${plugin_upper//-/_}"
            
            local accent_var="POWERKIT_PLUGIN_${plugin_upper}_ACCENT_COLOR"
            local accent_icon_var="POWERKIT_PLUGIN_${plugin_upper}_ACCENT_COLOR_ICON"
            local icon_var="POWERKIT_PLUGIN_${plugin_upper}_ICON"
            
            local accent_color="${!accent_var:-accent}"
            local accent_icon_color="${!accent_icon_var:-accent}"
            local icon="${!icon_var:-}"
            
            # Use format: name:accent:accent_icon:icon:type
            plugin_configs+="$plugin:$accent_color:$accent_icon_color:$icon:$plugin_type;"
        fi
    done
    
    # Remove trailing semicolon
    plugin_configs="${plugin_configs%%;}"
    
    if [[ -n "$plugin_configs" ]]; then
        # Build tmux command string that will be executed periodically
        # Include pane_current_path to force cache invalidation when path changes
        local text_color=$(get_powerkit_color 'text')
        local status_bg=$(get_powerkit_color 'surface')
        local transparent=$(get_tmux_option "@powerkit_transparent_status_bar" "false")
        local palette=$(serialize_powerkit_palette)
        local right_sep=$(get_tmux_option "@powerkit_right_separator" "$POWERKIT_DEFAULT_RIGHT_SEPARATOR")
        local right_sep_inv=$(get_tmux_option "@powerkit_right_separator_inverse" "$POWERKIT_DEFAULT_RIGHT_SEPARATOR_INVERSE")
        
        # Create command that tmux will execute with current pane path context
        printf "#(RENDER_TEXT_COLOR='%s' RENDER_STATUS_BG='%s' RENDER_TRANSPARENT='%s' RENDER_PALETTE='%s' POWERKIT_DEFAULT_RIGHT_SEPARATOR='%s' POWERKIT_DEFAULT_RIGHT_SEPARATOR_INVERSE='%s' %s/render_plugins.sh '%s' 2>/dev/null || true)" \
            "$text_color" "$status_bg" "$transparent" "$palette" "$right_sep" "$right_sep_inv" "$CURRENT_DIR" "$plugin_configs"
    fi
}

# Get plugins list for double layout (second status line)
get_plugins_list_double() {
    # For double layout, plugins go on the second line
    get_plugins_list "$@"
}

# Serialize PowerKit palette for render_plugins.sh
serialize_powerkit_palette() {
    local palette=""
    
    # Ensure theme is loaded
    if [[ -z "${POWERKIT_THEME_COLORS+x}" ]] || [[ "${#POWERKIT_THEME_COLORS[@]}" -eq 0 ]]; then
        load_powerkit_theme
    fi
    
    # Iterate over all theme colors and serialize them
    # Sort keys to ensure consistent ordering (important for parsing)
    for color in $(printf '%s\n' "${!POWERKIT_THEME_COLORS[@]}" | sort); do
        local color_value="${POWERKIT_THEME_COLORS[$color]}"
        # Skip empty values
        [[ -n "$color_value" ]] && palette+="$color=$color_value;"
    done
    
    echo "${palette%%;}"
}

# Initialize plugin system
initialize_plugins() {
    local powerkit_disable_plugins=$(get_tmux_option "@powerkit_disable_plugins" "$POWERKIT_DEFAULT_DISABLE_PLUGINS")
    local plugins_string=$(get_tmux_option "@powerkit_plugins" "$POWERKIT_DEFAULT_PLUGINS")
    local plugins
    IFS=',' read -r -a plugins <<<"$plugins_string"
    
    local status_output=""
    if [[ -n "$plugins_string" && "$powerkit_disable_plugins" != "true" ]]; then
        export CURRENT_DIR
        local powerkit_bar_layout=$(get_tmux_option "@powerkit_bar_layout" "$POWERKIT_DEFAULT_BAR_LAYOUT")
        
        if [[ "$powerkit_bar_layout" == "double" ]]; then
            # Double layout - plugins on second line
            status_output=$(get_plugins_list_double "${plugins[@]}")
        else
            # Single layout - plugins on right side
            status_output=$(get_plugins_list "${plugins[@]}")
        fi
    fi
    
    echo "$status_output"
}

# =============================================================================
# TMUX CONFIGURATION SYSTEM
# Applies all settings to tmux
# =============================================================================

# Configure tmux appearance settings
configure_tmux_appearance() {
    # Load PowerKit theme
    load_powerkit_theme
    
    # Pane borders
    local border_style_active_pane_default=$(get_powerkit_color 'border-strong')
    local border_style_inactive_pane_default=$(get_powerkit_color 'surface')
    local border_style_active_pane=$(get_tmux_option "@powerkit_active_pane_border_style" "$border_style_active_pane_default")
    local border_style_inactive_pane=$(get_tmux_option "@powerkit_inactive_pane_border_style" "$border_style_inactive_pane_default")
    
    tmux set-option -g pane-active-border-style "fg=$border_style_active_pane"
    if ! tmux set-option -g pane-border-style "#{?pane_synchronized,fg=$border_style_active_pane,fg=$border_style_inactive_pane}" &>/dev/null; then
        tmux set-option -g pane-border-style "fg=$border_style_active_pane,fg=$border_style_inactive_pane"
    fi
    
    # Message styling
    local message_bg=$(get_powerkit_color "error")
    local message_fg=$(get_powerkit_color "background-alt")
    tmux set-option -g message-style "bg=${message_bg},fg=${message_fg}"
    
    # Status bar
    local transparent=$(get_tmux_option "@powerkit_transparent_status_bar" "$POWERKIT_DEFAULT_TRANSPARENT")
    local status_bar_bg=$(get_powerkit_color "surface")
    local status_bar_fg=$(get_powerkit_color "text")
    if [[ "$transparent" == "true" ]]; then
        status_bar_bg="default"
    fi
    tmux set-option -g status-style "bg=${status_bar_bg},fg=${status_bar_fg}"
    
    # Status bar layout
    local powerkit_bar_layout=$(get_tmux_option "@powerkit_bar_layout" "$POWERKIT_DEFAULT_BAR_LAYOUT")
    if [[ "$powerkit_bar_layout" == "double" ]]; then
        tmux set-option -g status 2
    else
        tmux set-option -g status on
        tmux set-option -gu status-format[1] 2>/dev/null || true
    fi
    
    # Status bar lengths
    local status_left_length=$(get_tmux_option "@powerkit_status_left_length" "$POWERKIT_DEFAULT_STATUS_LEFT_LENGTH")
    local status_right_length=$(get_tmux_option "@powerkit_status_right_length" "$POWERKIT_DEFAULT_STATUS_RIGHT_LENGTH")
    tmux set-option -g status-left-length "$status_left_length"
    tmux set-option -g status-right-length "$status_right_length"
    
    # Window activity/bell styles
    local window_with_activity_style=$(get_tmux_option "@powerkit_window_with_activity_style" "$POWERKIT_DEFAULT_WINDOW_WITH_ACTIVITY_STYLE")
    local window_status_bell_style=$(get_tmux_option "@powerkit_status_bell_style" "$POWERKIT_DEFAULT_STATUS_BELL_STYLE")
    tmux set-window-option -g window-status-activity-style "$window_with_activity_style"
    tmux set-window-option -g window-status-bell-style "$window_status_bell_style"
}

# =============================================================================
# MAIN STATUS FORMAT BUILDER
# Assembles complete status bar format
# =============================================================================

# Build complete status format for single layout
build_single_layout_status_format() {
    local resolved_accent_color="$1"
    local left_format window_list_format inactive_window_format right_format final_separator
    
    left_format=$(build_status_left_format)
    window_list_format=$(build_window_list_format)
    inactive_window_format=$(build_tmux_window_format)
    right_format=$(build_status_right_format "$resolved_accent_color")
    
    # Create the final separator using proper architecture
    final_separator=$(create_final_separator)
    
    printf '%s%s%s%s%s' "$left_format" "$window_list_format" "$inactive_window_format" "$final_separator" "$right_format"
}

# Build complete status format for double layout (windows only)
build_double_layout_windows_format() {
    local left_format window_list_format inactive_window_format
    
    left_format=$(build_status_left_format)
    window_list_format=$(build_window_list_format)
    inactive_window_format=$(build_tmux_window_format)
    
    printf '%s%s%s#[nolist align=right range=right #{E:status-right-style}]#[push-default]#[pop-default]#[norange default]' "$left_format" "$window_list_format" "$inactive_window_format"
}

# =============================================================================
# INITIALIZATION SYSTEM
# Main entry point that configures everything
# =============================================================================

# Main initialization function
initialize_powerkit() {
    # Configure tmux appearance
    configure_tmux_appearance
    
    # Set up window formats using new modular system
    tmux set-window-option -g window-status-format "$(create_inactive_window_format)"
    tmux set-window-option -g window-status-current-format "$(create_active_window_format)"
    
    # Set up session segment (left side)
    tmux set-option -g status-left "$(create_session_segment)"
    
    # Initialize plugins and handle status bar layout
    local status_2=$(initialize_plugins)
    local powerkit_bar_layout=$(get_tmux_option "@powerkit_bar_layout" "$POWERKIT_DEFAULT_BAR_LAYOUT")
    
    if [[ "$powerkit_bar_layout" == "double" ]]; then
        # Double layout: plugins on second line
        if [[ -n "$status_2" ]]; then
            tmux set-option -g status-format[1] "$status_2"
        fi
        tmux set-option -g status-right ""
    else
        # Single layout: plugins on right side, with final separator
        if [[ -n "$status_2" ]]; then
            tmux set-option -g status-right "$status_2"
        else
            tmux set-option -g status-right ""
        fi
        
        # Apply complete status format with final separator
        local resolved_accent_color=$(get_powerkit_color 'surface')
        local complete_format=$(build_single_layout_status_format "$resolved_accent_color")
        tmux set-option -g status-format[0] "$complete_format"
    fi
    
    # Remove window separator for seamless powerline appearance
    tmux set-window-option -g window-status-separator ""
}

# =============================================================================
# HELPER KEYBINDINGS
# Register keybindings for interactive helpers
# =============================================================================

register_helper_keybindings() {
    local helpers_dir="$CURRENT_DIR/helpers"
    
    # Options viewer (prefix + O)
    local options_key=$(get_tmux_option "@powerkit_options_key" "$POWERKIT_DEFAULT_OPTIONS_KEY")
    local options_width=$(get_tmux_option "@powerkit_options_width" "$POWERKIT_DEFAULT_OPTIONS_WIDTH")
    local options_height=$(get_tmux_option "@powerkit_options_height" "$POWERKIT_DEFAULT_OPTIONS_HEIGHT")
    [[ -n "$options_key" ]] && tmux bind-key "$options_key" display-popup -E -w "$options_width" -h "$options_height" \
        "bash '$helpers_dir/options_viewer.sh'"
    
    # Keybindings viewer (prefix + B)
    local keybindings_key=$(get_tmux_option "@powerkit_keybindings_key" "$POWERKIT_DEFAULT_KEYBINDINGS_KEY")
    local keybindings_width=$(get_tmux_option "@powerkit_keybindings_width" "$POWERKIT_DEFAULT_KEYBINDINGS_WIDTH")
    local keybindings_height=$(get_tmux_option "@powerkit_keybindings_height" "$POWERKIT_DEFAULT_KEYBINDINGS_HEIGHT")
    [[ -n "$keybindings_key" ]] && tmux bind-key "$keybindings_key" display-popup -E -w "$keybindings_width" -h "$keybindings_height" \
        "bash '$helpers_dir/keybindings_viewer.sh'"
}

# =============================================================================
# EXECUTE INITIALIZATION 
# =============================================================================

# Initialize the complete PowerKit system
initialize_powerkit

# Register helper keybindings
register_helper_keybindings

# Register cache clear keybinding
setup_cache_keybinding

