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

# Colors for output
BOLD='\033[1m'
DIM='\033[2m'
CYAN='\033[36m'
GREEN='\033[32m'

RESET='\033[0m'

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
    "@theme_variation|night|night,storm,moon,day|Color scheme variation"
    "@theme_plugins|datetime,weather|(comma-separated plugin names)|Enabled plugins"
    "@theme_disable_plugins|0|0,1|Disable all plugins"
    "@theme_transparent_status_bar|false|true,false|Transparent status bar"
    "@theme_bar_layout|single|single,double|Status bar layout"
    "@theme_status_left_length|100|(integer)|Maximum left status length"
    "@theme_status_right_length|250|(integer)|Maximum right status length"
    
    # Separators
    "@theme_left_separator||Powerline character|Left separator"
    "@theme_right_separator||Powerline character|Right separator"
    "@theme_transparent_left_separator_inverse||Powerline character|Inverse left separator"
    "@theme_transparent_right_separator_inverse||Powerline character|Inverse right separator"
    
    # Session & Window
    "@theme_session_icon| |Icon/emoji|Session icon"
    "@theme_active_window_icon||(Icon/emoji)|Active window icon"
    "@theme_inactive_window_icon||(Icon/emoji)|Inactive window icon"
    "@theme_zoomed_window_icon||(Icon/emoji)|Zoomed window icon"
    "@theme_pane_synchronized_icon|✵|Icon/emoji|Synchronized panes icon"
    "@theme_active_window_title|#W |tmux format|Active window title format"
    "@theme_inactive_window_title|#W |tmux format|Inactive window title format"
    "@theme_window_with_activity_style|italics|italics,bold,none|Activity window style"
    "@theme_status_bell_style|bold|bold,italics,none|Bell status style"
    "@theme_active_pane_border_style|dark5|palette color|Active pane border color"
    "@theme_inactive_pane_border_style|bg_highlight|palette color|Inactive pane border color"
)

declare -a PLUGIN_OPTIONS=(
    # Datetime
    "@theme_plugin_datetime_icon|󰥔|Icon|Datetime icon"
    "@theme_plugin_datetime_accent_color|blue7|palette color|Datetime background"
    "@theme_plugin_datetime_accent_color_icon|blue0|palette color|Datetime icon background"
    "@theme_plugin_datetime_format|datetime|time,time-seconds,time-12h,date,date-full,date-iso,datetime,weekday,full,iso,(strftime)|Date/time format"
    "@theme_plugin_datetime_timezone||(timezone name)|Secondary timezone"
    "@theme_plugin_datetime_show_week|false|true,false|Show week number"
    "@theme_plugin_datetime_separator| |(string)|Element separator"
    
    # Weather
    "@theme_plugin_weather_icon|󰖐|Icon|Weather icon"
    "@theme_plugin_weather_accent_color|blue7|palette color|Weather background"
    "@theme_plugin_weather_accent_color_icon|blue0|palette color|Weather icon background"
    "@theme_plugin_weather_location||(city name)|Weather location"
    "@theme_plugin_weather_unit||u,m,M|Temperature unit"
    "@theme_plugin_weather_format|compact|compact,full,minimal,detailed,(wttr.in format)|Weather format"
    "@theme_plugin_weather_cache_ttl|900|(seconds)|Cache duration"
    
    # Battery
    "@theme_plugin_battery_icon|󰁹|Icon|Battery icon"
    "@theme_plugin_battery_accent_color|blue7|palette color|Battery background"
    "@theme_plugin_battery_accent_color_icon|blue0|palette color|Battery icon background"
    "@theme_plugin_battery_display_mode|percentage|percentage,time|Display mode"
    "@theme_plugin_battery_icon_charging|󰂄|Icon|Charging icon"
    "@theme_plugin_battery_low_threshold|30|0-100|Low battery threshold"
    "@theme_plugin_battery_icon_low|󰂃|Icon|Low battery icon"
    "@theme_plugin_battery_low_accent_color|red|palette color|Low battery background"
    "@theme_plugin_battery_low_accent_color_icon|red1|palette color|Low battery icon background"
    "@theme_plugin_battery_cache_ttl|30|(seconds)|Cache duration"
    
    # CPU
    "@theme_plugin_cpu_icon||Icon|CPU icon"
    "@theme_plugin_cpu_accent_color|blue7|palette color|CPU background"
    "@theme_plugin_cpu_accent_color_icon|blue0|palette color|CPU icon background"
    "@theme_plugin_cpu_cache_ttl|2|(seconds)|Cache duration"
    "@theme_plugin_cpu_warning_threshold|70|0-100|Warning threshold"
    "@theme_plugin_cpu_critical_threshold|90|0-100|Critical threshold"
    "@theme_plugin_cpu_warning_accent_color|yellow|palette color|Warning background"
    "@theme_plugin_cpu_warning_accent_color_icon|orange|palette color|Warning icon background"
    "@theme_plugin_cpu_critical_accent_color|red|palette color|Critical background"
    "@theme_plugin_cpu_critical_accent_color_icon|red1|palette color|Critical icon background"
    
    # Memory
    "@theme_plugin_memory_icon||Icon|Memory icon"
    "@theme_plugin_memory_accent_color|blue7|palette color|Memory background"
    "@theme_plugin_memory_accent_color_icon|blue0|palette color|Memory icon background"
    "@theme_plugin_memory_format|percent|percent,usage|Memory format"
    "@theme_plugin_memory_cache_ttl|5|(seconds)|Cache duration"
    "@theme_plugin_memory_warning_threshold|70|0-100|Warning threshold"
    "@theme_plugin_memory_critical_threshold|90|0-100|Critical threshold"
    "@theme_plugin_memory_warning_accent_color|yellow|palette color|Warning background"
    "@theme_plugin_memory_warning_accent_color_icon|orange|palette color|Warning icon background"
    "@theme_plugin_memory_critical_accent_color|red|palette color|Critical background"
    "@theme_plugin_memory_critical_accent_color_icon|red1|palette color|Critical icon background"
    
    # Disk
    "@theme_plugin_disk_icon|󰋊|Icon|Disk icon"
    "@theme_plugin_disk_accent_color|blue7|palette color|Disk background"
    "@theme_plugin_disk_accent_color_icon|blue0|palette color|Disk icon background"
    "@theme_plugin_disk_mount|/|(mount path)|Mount point to monitor"
    "@theme_plugin_disk_format|percent|percent,usage,free|Disk format"
    "@theme_plugin_disk_cache_ttl|60|(seconds)|Cache duration"
    "@theme_plugin_disk_warning_threshold|70|0-100|Warning threshold"
    "@theme_plugin_disk_critical_threshold|90|0-100|Critical threshold"
    "@theme_plugin_disk_warning_accent_color|yellow|palette color|Warning background"
    "@theme_plugin_disk_warning_accent_color_icon|orange|palette color|Warning icon background"
    "@theme_plugin_disk_critical_accent_color|red|palette color|Critical background"
    "@theme_plugin_disk_critical_accent_color_icon|red1|palette color|Critical icon background"
    
    # Network
    "@theme_plugin_network_icon|󰛳|Icon|Network icon"
    "@theme_plugin_network_accent_color|blue7|palette color|Network background"
    "@theme_plugin_network_accent_color_icon|blue0|palette color|Network icon background"
    "@theme_plugin_network_interface||(interface name)|Network interface"
    "@theme_plugin_network_cache_ttl|2|(seconds)|Cache duration"
    
    # Load Average
    "@theme_plugin_loadavg_icon|󰊚|Icon|Load average icon"
    "@theme_plugin_loadavg_accent_color|blue7|palette color|Load average background"
    "@theme_plugin_loadavg_accent_color_icon|blue0|palette color|Load average icon background"
    "@theme_plugin_loadavg_format|1|1,5,15,all|Load average format"
    "@theme_plugin_loadavg_cache_ttl|5|(seconds)|Cache duration"
    "@theme_plugin_loadavg_warning_threshold_multiplier|2|(multiplier)|Warning threshold (x CPU cores)"
    "@theme_plugin_loadavg_critical_threshold_multiplier|4|(multiplier)|Critical threshold (x CPU cores)"
    "@theme_plugin_loadavg_warning_accent_color|yellow|palette color|Warning background"
    "@theme_plugin_loadavg_warning_accent_color_icon|orange|palette color|Warning icon background"
    "@theme_plugin_loadavg_critical_accent_color|red|palette color|Critical background"
    "@theme_plugin_loadavg_critical_accent_color_icon|red1|palette color|Critical icon background"
    
    # Uptime
    "@theme_plugin_uptime_icon|󰔟|Icon|Uptime icon"
    "@theme_plugin_uptime_accent_color|blue7|palette color|Uptime background"
    "@theme_plugin_uptime_accent_color_icon|blue0|palette color|Uptime icon background"
    "@theme_plugin_uptime_cache_ttl|60|(seconds)|Cache duration"
    
    # Git
    "@theme_plugin_git_icon||Icon|Git icon"
    "@theme_plugin_git_accent_color|blue7|palette color|Git background"
    "@theme_plugin_git_accent_color_icon|blue0|palette color|Git icon background"
    "@theme_plugin_git_cache_ttl|5|(seconds)|Cache duration"
    
    # Docker
    "@theme_plugin_docker_icon||Icon|Docker icon"
    "@theme_plugin_docker_accent_color|blue7|palette color|Docker background"
    "@theme_plugin_docker_accent_color_icon|blue0|palette color|Docker icon background"
    "@theme_plugin_docker_cache_ttl|10|(seconds)|Cache duration"
    
    # Kubernetes
    "@theme_plugin_kubernetes_icon|󱃾|Icon|Kubernetes icon"
    "@theme_plugin_kubernetes_accent_color|blue7|palette color|Kubernetes background"
    "@theme_plugin_kubernetes_accent_color_icon|blue0|palette color|Kubernetes icon background"
    "@theme_plugin_kubernetes_display_mode|connected|always,connected,context|Display mode"
    "@theme_plugin_kubernetes_show_namespace|false|true,false|Show namespace"
    "@theme_plugin_kubernetes_connectivity_timeout|2|(seconds)|Connection timeout"
    "@theme_plugin_kubernetes_connectivity_cache_ttl|300|(seconds)|Connectivity cache duration"
    "@theme_plugin_kubernetes_cache_ttl|30|(seconds)|Cache duration"
    "@theme_plugin_kubernetes_context_selector_key|K|(key)|Context selector keybinding"
    "@theme_plugin_kubernetes_context_selector_width|50%|(percentage)|Context selector width"
    "@theme_plugin_kubernetes_context_selector_height|50%|(percentage)|Context selector height"
    "@theme_plugin_kubernetes_namespace_selector_key|N|(key)|Namespace selector keybinding"
    "@theme_plugin_kubernetes_namespace_selector_width|50%|(percentage)|Namespace selector width"
    "@theme_plugin_kubernetes_namespace_selector_height|50%|(percentage)|Namespace selector height"
    
    # Hostname
    "@theme_plugin_hostname_icon||Icon|Hostname icon"
    "@theme_plugin_hostname_accent_color|blue7|palette color|Hostname background"
    "@theme_plugin_hostname_accent_color_icon|blue0|palette color|Hostname icon background"
    "@theme_plugin_hostname_format|short|short,full|Hostname format"
    
    # Homebrew
    "@theme_plugin_homebrew_icon|󰚰|Icon|Homebrew icon"
    "@theme_plugin_homebrew_accent_color|blue7|palette color|Homebrew background"
    "@theme_plugin_homebrew_accent_color_icon|blue0|palette color|Homebrew icon background"
    "@theme_plugin_homebrew_additional_options|--greedy|(brew options)|Additional brew options"
    "@theme_plugin_homebrew_cache_ttl|1800|(seconds)|Cache duration"
    
    # Yay
    "@theme_plugin_yay_icon|󰚰|Icon|Yay icon"
    "@theme_plugin_yay_accent_color|blue7|palette color|Yay background"
    "@theme_plugin_yay_accent_color_icon|blue0|palette color|Yay icon background"
    "@theme_plugin_yay_cache_ttl|1800|(seconds)|Cache duration"
    
    # Spotify
    "@theme_plugin_spotify_icon|󰝚|Icon|Spotify icon"
    "@theme_plugin_spotify_accent_color|blue7|palette color|Spotify background"
    "@theme_plugin_spotify_accent_color_icon|blue0|palette color|Spotify icon background"
    "@theme_plugin_spotify_format|%artist% - %track%|%artist%,%track%,%album%|Display format"
    "@theme_plugin_spotify_max_length|40|(integer)|Maximum text length"
    "@theme_plugin_spotify_not_playing||(string)|Text when not playing"
    "@theme_plugin_spotify_backend|auto|auto,osascript,playerctl,spt,shpotify|Backend"
    "@theme_plugin_spotify_cache_ttl|5|(seconds)|Cache duration"
    
    # Spt
    "@theme_plugin_spt_icon|󰝚|Icon|Spt icon"
    "@theme_plugin_spt_accent_color|blue7|palette color|Spt background"
    "@theme_plugin_spt_accent_color_icon|blue0|palette color|Spt icon background"
    "@theme_plugin_spt_format|%a - %t|%a,%t,%b|Display format"
    "@theme_plugin_spt_cache_ttl|5|(seconds)|Cache duration"
    
    # Playerctl
    "@theme_plugin_playerctl_icon|󰝚|Icon|Playerctl icon"
    "@theme_plugin_playerctl_accent_color|blue7|palette color|Playerctl background"
    "@theme_plugin_playerctl_accent_color_icon|blue0|palette color|Playerctl icon background"
    "@theme_plugin_playerctl_format|{{artist}} - {{title}}|{{artist}},{{title}},{{album}}|Display format"
    "@theme_plugin_playerctl_ignore_players|IGNORE|(player names)|Players to ignore"
    "@theme_plugin_playerctl_cache_ttl|5|(seconds)|Cache duration"
)

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
    
    printf "${GREEN}%-50s${RESET}" "$option"
    
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
    
    printf "${GREEN}%-50s${RESET}" "$option"
    
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
    
    # Plugin options - group by plugin
    local current_plugin=""
    for opt in "${PLUGIN_OPTIONS[@]}"; do
        IFS='|' read -r option default possible description <<< "$opt"
        
        # Extract plugin name using parameter expansion
        local plugin_name
        local temp="${option#@theme_plugin_}"
        plugin_name="${temp%%_*}"
        
        if [[ "$plugin_name" != "$current_plugin" ]]; then
            current_plugin="$plugin_name"
            print_section "Theme Plugin: ${current_plugin^}" "$MAGENTA"
        fi
        
        if [[ -z "$filter" ]] || [[ "$option" == *"$filter"* ]] || [[ "$description" == *"$filter"* ]]; then
            print_option "$option" "$default" "$possible" "$description"
        fi
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
