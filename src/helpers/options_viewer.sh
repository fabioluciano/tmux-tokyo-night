#!/usr/bin/env bash
# =============================================================================
# Tokyo Night Theme Options Viewer
# Displays all available theme options with defaults and current values
# Also shows options from all TPM plugins installed
# =============================================================================

set -euo pipefail

CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$CURRENT_DIR/.." && pwd)"

# shellcheck source=src/defaults.sh
. "$ROOT_DIR/defaults.sh"
# shellcheck source=src/utils.sh
. "$ROOT_DIR/utils.sh"

# Colors for output (from defaults.sh)
BOLD="$POWERKIT_ANSI_BOLD"
DIM="$POWERKIT_ANSI_DIM"
CYAN="$POWERKIT_ANSI_CYAN"
GREEN="$POWERKIT_ANSI_GREEN"
MAGENTA="$POWERKIT_ANSI_MAGENTA"
YELLOW="$POWERKIT_ANSI_YELLOW"
# RED="$POWERKIT_ANSI_RED"  # Unused
BLUE="$POWERKIT_ANSI_BLUE"

RESET="$POWERKIT_ANSI_RESET"

# TPM plugins directory
TPM_PLUGINS_DIR="${TMUX_PLUGIN_MANAGER_PATH:-$HOME/.tmux/plugins}"
# Also check common alternative location
if [[ ! -d "$TPM_PLUGINS_DIR" ]] && [[ -d "$HOME/.config/tmux/plugins" ]]; then
    TPM_PLUGINS_DIR="$HOME/.config/tmux/plugins"
fi

# =============================================================================
# Option definitions with metadata
# Format: "tmux_option|default_value|possible_values|description"
# =============================================================================

declare -a THEME_OPTIONS=(
    # Core options
    "@powerkit_variation|night|night,storm,moon,day|Color scheme variation"
    "@powerkit_plugins|datetime,weather|(comma-separated plugin names)|Enabled plugins"
    "@powerkit_disable_plugins|0|0,1|Disable all plugins"
    "@powerkit_transparent_status_bar|false|true,false|Transparent status bar"
    "@powerkit_bar_layout|single|single,double|Status bar layout"
    "@powerkit_status_left_length|100|(integer)|Maximum left status length"
    "@powerkit_status_right_length|250|(integer)|Maximum right status length"
    
    # Separators
    "@powerkit_left_separator||Powerline character|Left separator"
    "@powerkit_right_separator||Powerline character|Right separator"
    "@powerkit_transparent_left_separator_inverse||Powerline character|Inverse left separator"
    "@powerkit_transparent_right_separator_inverse||Powerline character|Inverse right separator"
    
    # Session & Window
    "@powerkit_session_icon| |Icon/emoji|Session icon"
    "@powerkit_active_window_icon||(Icon/emoji)|Active window icon"
    "@powerkit_inactive_window_icon||(Icon/emoji)|Inactive window icon"
    "@powerkit_zoomed_window_icon||(Icon/emoji)|Zoomed window icon"
    "@powerkit_pane_synchronized_icon|✵|Icon/emoji|Synchronized panes icon"
    "@powerkit_active_window_title|#W |tmux format|Active window title format"
    "@powerkit_inactive_window_title|#W |tmux format|Inactive window title format"
    "@powerkit_window_with_activity_style|italics|italics,bold,none|Activity window style"
    "@powerkit_status_bell_style|bold|bold,italics,none|Bell status style"
    "@powerkit_active_pane_border_style|dark5|palette color|Active pane border color"
    "@powerkit_inactive_pane_border_style|bg_highlight|palette color|Inactive pane border color"
)

# =============================================================================
# Dynamic Plugin Option Discovery
# =============================================================================

discover_tokyo_night_plugin_options() {
    local plugin_dir="$ROOT_DIR"
    local -A plugin_options=()
    local -A default_values=()
    
    # Scan defaults.sh for PLUGIN_ constants
    if [[ -f "$plugin_dir/defaults.sh" ]]; then
        while IFS= read -r line; do
            if [[ "$line" =~ ^[[:space:]]*PLUGIN_([A-Z_]+)_([A-Z_]+)[[:space:]]*=[[:space:]]*[\"\']?([^\"\']*)[\"\']? ]]; then
                local plugin_part="${BASH_REMATCH[1]}"
                local option_part="${BASH_REMATCH[2]}"
                local value="${BASH_REMATCH[3]}"
                
                # Convert to lowercase and create option name
                local plugin_name option_name
                plugin_name=$(echo "$plugin_part" | tr '[:upper:]' '[:lower:]')
                option_name=$(echo "$option_part" | tr '[:upper:]' '[:lower:]')
                local option="@powerkit_plugin_${plugin_name}_${option_name}"
                
                plugin_options["$option"]=1
                default_values["$option"]="$value"
            fi
        done < "$plugin_dir/defaults.sh"
    fi
    
    # Scan plugin files for get_tmux_option calls
    while IFS= read -r file; do
        while IFS= read -r line; do
            # Look for get_tmux_option calls
            if [[ "$line" =~ get_tmux_option[[:space:]]+[\"\'](@powerkit_plugin_[a-zA-Z0-9_]+)[\"\'][[:space:]]+[\"\']([^\"]*)[\"\'] ]] || \
               [[ "$line" =~ get_tmux_option[[:space:]]+[\"](@powerkit_plugin_[a-zA-Z0-9_]+)[\"][[:space:]]+[\"]([^\"]*)[\"] ]] || \
               [[ "$line" =~ get_tmux_option[[:space:]]+[\'](@powerkit_plugin_[a-zA-Z0-9_]+)[\'][[:space:]]+[\']([^\']*)[\'] ]]; then
                local option="${BASH_REMATCH[1]}"
                local default="${BASH_REMATCH[2]}"
                plugin_options["$option"]=1
                [[ -z "${default_values[$option]:-}" ]] && default_values["$option"]="$default"
            fi
        done < "$file"
    done < <(find "$plugin_dir/plugin" -name "*.sh" -type f 2>/dev/null | head -"$POWERKIT_PERF_OPTIONS_PLUGIN_LIMIT")
    
    # Convert to global array for compatibility
    declare -g -a DISCOVERED_PLUGIN_OPTIONS=()
    for option in $(printf '%s\n' "${!plugin_options[@]}" | sort); do
        local default="${default_values[$option]:-}"
        DISCOVERED_PLUGIN_OPTIONS+=("$option|$default||Plugin option")
    done
}

# =============================================================================
# Helper Functions
# =============================================================================

print_header() {
    echo -e "\n${BOLD}${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo -e "${BOLD}${CYAN}  🌃 tmux Options Reference${RESET}"
    echo -e "${BOLD}${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo -e "${DIM}  Plugins directory: ${TPM_PLUGINS_DIR}${RESET}\n"
}

print_section() {
    local title="$1"
    local color="${2:-$MAGENTA}"
    echo -e "\n${BOLD}${color}▸ ${title}${RESET}"
    echo -e "${DIM}─────────────────────────────────────────────────────────────────────────────${RESET}"
}

print_option() {
    local option="$1"
    local default="$2"
    local possible="$3"
    local description="$4"
    local current
    
    current=$(tmux show-option -gqv "$option" 2>/dev/null || echo "")
    
    printf "${GREEN}%-${POWERKIT_FORMAT_OPTION_WIDTH}s${RESET}" "$option"
    
    if [[ -n "$current" && "$current" != "$default" ]]; then
        echo -e " ${YELLOW}= $current${RESET} ${DIM}(default: $default)${RESET}"
    else
        echo -e " ${DIM}= $default${RESET}"
    fi
    
    if [[ -n "$description" ]]; then
        echo -e "  ${DIM}↳ $description${RESET}"
    fi
    if [[ -n "$possible" ]]; then
        echo -e "  ${DIM}  Values: $possible${RESET}"
    fi
}

print_tpm_option() {
    local option="$1"
    local current
    
    # Get current value from tmux (includes values set by plugins at runtime)
    current=$(tmux show-option -gqv "$option" 2>/dev/null || echo "")
    
    printf "${GREEN}%-${POWERKIT_FORMAT_OPTION_WIDTH}s${RESET}" "$option"
    
    if [[ -n "$current" ]]; then
        echo -e " ${YELLOW}= $current${RESET}"
    else
        echo -e " ${DIM}(not set)${RESET}"
    fi
}

# =============================================================================
# TPM Plugin Scanner
# =============================================================================

scan_tpm_plugin_options() {
    local plugin_dir="$1"
    local plugin_name
    plugin_name=$(basename "$plugin_dir")
    
    # Skip tpm itself and our theme (handled separately)
    if [[ "$plugin_name" == "tpm" ]] || [[ "$plugin_name" == "tmux-tokyo-night" ]]; then
        return
    fi
    
    # Find all @ options in the plugin (only in text files, exclude .git)
    local options=()
    while IFS= read -r opt; do
        # Filter out invalid options (must start with lowercase/uppercase letter after @)
        # and exclude common false positives
        if [[ "$opt" =~ ^@[a-z][a-z0-9_-]*$ ]] && \
           [[ ! "$opt" =~ ^@(ARGV|files|github|naoimporta|plugin)$ ]] && \
           [[ ! "$opt" =~ ^@[a-z]+$ ]] || [[ "$opt" =~ ^@[a-z]+-[a-z] ]] || [[ "$opt" =~ ^@[a-z]+_[a-z] ]]; then
            # Only include if it looks like a real option (has - or _ or is a known pattern)
            if [[ "$opt" =~ [-_] ]] || [[ ${#opt} -gt 10 ]]; then
                options+=("$opt")
            fi
        fi
    done < <(grep -rhI --include='*.sh' --include='*.tmux' --include='*.md' --include='*.py' -oE '@[a-z][a-z0-9_-]+' "$plugin_dir" 2>/dev/null | sort -u)
    
    if [[ ${#options[@]} -gt 0 ]]; then
        print_section "📦 ${plugin_name}" "$BLUE"
        for opt in "${options[@]}"; do
            print_tpm_option "$opt"
        done
    fi
}

# =============================================================================
# Main Display Function
# =============================================================================

display_options() {
    local filter="${1:-}"
    
    print_header
    
    # =========================================================================
    # Tokyo Night Theme Options
    # =========================================================================
    echo -e "${BOLD}${CYAN}╔═══════════════════════════════════════════════════════════════════════════╗${RESET}"
    echo -e "${BOLD}${CYAN}║  🌃 Tokyo Night Theme Options                                             ║${RESET}"
    echo -e "${BOLD}${CYAN}╚═══════════════════════════════════════════════════════════════════════════╝${RESET}"
    
    # Theme options
    print_section "Theme Core Options" "$MAGENTA"
    for opt in "${THEME_OPTIONS[@]}"; do
        IFS='|' read -r option default possible description <<< "$opt"
        
        if [[ -z "$filter" ]] || [[ "$option" == *"$filter"* ]] || [[ "$description" == *"$filter"* ]]; then
            print_option "$option" "$default" "$possible" "$description"
        fi
    done
    
    # Discover plugin options dynamically
    discover_tokyo_night_plugin_options
    
    # Get all tmux options that start with @powerkit_plugin_
    local all_powerkit_plugin_options=()
    while IFS= read -r option_line; do
        if [[ "$option_line" =~ ^@powerkit_plugin_([a-zA-Z0-9_]+) ]]; then
            local option="${option_line%% *}"
            all_powerkit_plugin_options+=("$option")
        fi
    done < <(tmux show-options -g 2>/dev/null | grep "^@powerkit_plugin_" || true)
    
    # Also add discovered options that might not be set yet
    for opt in "${DISCOVERED_PLUGIN_OPTIONS[@]}"; do
        IFS='|' read -r option default possible description <<< "$opt"
        if [[ ! " ${all_powerkit_plugin_options[*]} " =~ \ $option\  ]]; then
            all_powerkit_plugin_options+=("$option")
        fi
    done
    
    # Group and display plugin options
    local _current_plugin=""
    local -A grouped_options=()
    
    # Group options by plugin
    for option in "${all_powerkit_plugin_options[@]}"; do
        local temp="${option#@powerkit_plugin_}"
        local plugin_name="${temp%%_*}"
        
        if [[ -z "${grouped_options[$plugin_name]:-}" ]]; then
            grouped_options["$plugin_name"]="$option"
        else
            grouped_options["$plugin_name"]+=" $option"
        fi
    done
    
    # Display grouped options
    for plugin_name in $(printf '%s\n' "${!grouped_options[@]}" | sort); do
        local options_for_plugin="${grouped_options[$plugin_name]}"
        local has_visible_options=false
        
        # Check if any options match filter
        for option in $options_for_plugin; do
            if [[ -z "$filter" ]] || [[ "$option" == *"$filter"* ]]; then
                if [[ "$has_visible_options" == "false" ]]; then
                    print_section "Theme Plugin: ${plugin_name^}" "$MAGENTA"
                    has_visible_options=true
                fi
                
                # Get default from discovered options or defaults.sh
                local default_val=""
                for opt in "${DISCOVERED_PLUGIN_OPTIONS[@]}"; do
                    IFS='|' read -r opt_name opt_default _opt_possible _opt_description <<< "$opt"
                    if [[ "$opt_name" == "$option" ]]; then
                        default_val="$opt_default"
                        break
                    fi
                done
                
                print_option "$option" "$default_val" "" "Plugin option"
            fi
        done
    done
    
    # =========================================================================
    # Other TPM Plugins
    # =========================================================================
    echo -e "\n\n${BOLD}${BLUE}╔═══════════════════════════════════════════════════════════════════════════╗${RESET}"
    echo -e "${BOLD}${BLUE}║  📦 Other TPM Plugins Options                                             ║${RESET}"
    echo -e "${BOLD}${BLUE}╚═══════════════════════════════════════════════════════════════════════════╝${RESET}"
    
    if [[ -d "$TPM_PLUGINS_DIR" ]]; then
        for plugin_dir in "$TPM_PLUGINS_DIR"/*/; do
            if [[ -d "$plugin_dir" ]]; then
                scan_tpm_plugin_options "$plugin_dir"
            fi
        done
    else
        echo -e "\n${DIM}  No TPM plugins directory found at: $TPM_PLUGINS_DIR${RESET}"
    fi
    
    echo -e "\n${DIM}Press 'q' to exit, '/' to search, 'g' go to top, 'G' go to bottom${RESET}\n"
}

# =============================================================================
# Main
# =============================================================================

if [[ "${1:-}" == "--help" ]] || [[ "${1:-}" == "-h" ]]; then
    echo "Usage: $0 [filter]"
    echo "  filter: Optional string to filter options"
    exit 0
fi

# Use less with mouse support if available, otherwise fall back to regular less
if less --help 2>&1 | grep -q -- '--mouse'; then
    display_options "${1:-}" | less -R --mouse
else
    display_options "${1:-}" | less -R
fi
