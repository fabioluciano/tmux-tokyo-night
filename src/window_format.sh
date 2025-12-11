#!/usr/bin/env bash
# =============================================================================
# PowerKit Window Formatting
# Window index, content, and assembly systems
# =============================================================================

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
        echo "#[${index_colors},fg=${text_color},bold] #I "
    else
        echo "#[${index_colors},fg=${text_color}] #I "
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
