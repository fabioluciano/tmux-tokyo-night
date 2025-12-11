#!/usr/bin/env bash
# =============================================================================
# PowerKit Initialization
# Main entry point - orchestrates all PowerKit modules
# =============================================================================
set -euo pipefail
export LC_ALL=en_US.UTF-8

CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# =============================================================================
# Source Dependencies (order matters)
# =============================================================================
. "$CURRENT_DIR/defaults.sh"
. "$CURRENT_DIR/utils.sh"
. "$CURRENT_DIR/cache.sh"

# Module files
. "$CURRENT_DIR/keybindings.sh"
. "$CURRENT_DIR/separators.sh"
. "$CURRENT_DIR/window_format.sh"
. "$CURRENT_DIR/status_bar.sh"
. "$CURRENT_DIR/plugin_integration.sh"
. "$CURRENT_DIR/tmux_config.sh"

# =============================================================================
# MAIN INITIALIZATION
# =============================================================================

# Main initialization function
initialize_powerkit() {
    # Configure tmux appearance
    configure_tmux_appearance
    
    # Set up window formats using modular system
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
# EXECUTE INITIALIZATION 
# =============================================================================

# Check for keybinding conflicts before registering
plugins_string=$(get_tmux_option "@powerkit_plugins" "$POWERKIT_DEFAULT_PLUGINS")
check_keybinding_conflicts "$plugins_string"

# Initialize the complete PowerKit system
initialize_powerkit

# Register helper keybindings
register_helper_keybindings

# Register cache clear keybinding
setup_cache_keybinding
