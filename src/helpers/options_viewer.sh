#!/usr/bin/env bash
# Helper: options_viewer - Display all available theme options with defaults and current values

set -euo pipefail

CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$CURRENT_DIR/.." && pwd)"

. "$ROOT_DIR/defaults.sh"
. "$ROOT_DIR/utils.sh"

BOLD="$POWERKIT_ANSI_BOLD"; DIM="$POWERKIT_ANSI_DIM"; CYAN="$POWERKIT_ANSI_CYAN"
GREEN="$POWERKIT_ANSI_GREEN"; MAGENTA="$POWERKIT_ANSI_MAGENTA"; YELLOW="$POWERKIT_ANSI_YELLOW"
BLUE="$POWERKIT_ANSI_BLUE"; RESET="$POWERKIT_ANSI_RESET"

TPM_PLUGINS_DIR="${TMUX_PLUGIN_MANAGER_PATH:-$HOME/.tmux/plugins}"
[[ ! -d "$TPM_PLUGINS_DIR" && -d "$HOME/.config/tmux/plugins" ]] && TPM_PLUGINS_DIR="$HOME/.config/tmux/plugins"

declare -a THEME_OPTIONS=(
    "@powerkit_variation|night|night,storm,moon,day|Color scheme variation"
    "@powerkit_plugins|datetime,weather|(comma-separated)|Enabled plugins"
    "@powerkit_disable_plugins|0|0,1|Disable all plugins"
    "@powerkit_transparent_status_bar|false|true,false|Transparent status bar"
    "@powerkit_bar_layout|single|single,double|Status bar layout"
    "@powerkit_status_left_length|100|(integer)|Maximum left status length"
    "@powerkit_status_right_length|250|(integer)|Maximum right status length"
    "@powerkit_left_separator||Powerline|Left separator"
    "@powerkit_right_separator||Powerline|Right separator"
    "@powerkit_session_icon| |Icon/emoji|Session icon"
    "@powerkit_active_window_title|#W |tmux format|Active window title format"
    "@powerkit_inactive_window_title|#W |tmux format|Inactive window title format"
)

print_header() {
    echo -e "\n${BOLD}${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo -e "${BOLD}${CYAN}  🌃 tmux Options Reference${RESET}"
    echo -e "${BOLD}${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo -e "${DIM}  Plugins directory: ${TPM_PLUGINS_DIR}${RESET}\n"
}

print_section() { echo -e "\n${BOLD}${2:-$MAGENTA}▸ ${1}${RESET}\n${DIM}─────────────────────────────────────────────────────────────────────────────${RESET}"; }

print_option() {
    local option="$1" default="$2" possible="$3" description="$4"
    local current; current=$(tmux show-option -gqv "$option" 2>/dev/null || echo "")
    printf "${GREEN}%-45s${RESET}" "$option"
    [[ -n "$current" && "$current" != "$default" ]] && echo -e " ${YELLOW}= $current${RESET} ${DIM}(default: $default)${RESET}" || echo -e " ${DIM}= $default${RESET}"
    [[ -n "$description" ]] && echo -e "  ${DIM}↳ $description${RESET}"
    [[ -n "$possible" ]] && echo -e "  ${DIM}  Values: $possible${RESET}"
}

print_tpm_option() {
    local option="$1"; local current; current=$(tmux show-option -gqv "$option" 2>/dev/null || echo "")
    printf "${GREEN}%-45s${RESET}" "$option"
    [[ -n "$current" ]] && echo -e " ${YELLOW}= $current${RESET}" || echo -e " ${DIM}(not set)${RESET}"
}

discover_plugin_options() {
    local -A plugin_options=()
    while IFS= read -r file; do
        while IFS= read -r line; do
            if [[ "$line" =~ get_tmux_option[[:space:]]+[\"\'](@powerkit_plugin_[a-zA-Z0-9_]+) ]] || \
               [[ "$line" =~ get_cached_option[[:space:]]+[\"\'](@powerkit_plugin_[a-zA-Z0-9_]+) ]]; then
                plugin_options["${BASH_REMATCH[1]}"]=1
            fi
        done < "$file"
    done < <(find "$ROOT_DIR/plugin" -name "*.sh" -type f 2>/dev/null)
    printf '%s\n' "${!plugin_options[@]}" | sort
}

scan_tpm_plugin_options() {
    local plugin_dir="$1" plugin_name; plugin_name=$(basename "$plugin_dir")
    [[ "$plugin_name" == "tpm" || "$plugin_name" == "tmux-tokyo-night" ]] && return
    
    local -a options=()
    while IFS= read -r opt; do
        [[ "$opt" =~ [-_] ]] && [[ ${#opt} -gt 10 ]] && options+=("$opt")
    done < <(grep -rhI --include='*.sh' --include='*.tmux' -oE '@[a-z][a-z0-9_-]+' "$plugin_dir" 2>/dev/null | sort -u)
    
    if [[ ${#options[@]} -gt 0 ]]; then
        print_section "📦 ${plugin_name}" "$BLUE"
        for opt in "${options[@]}"; do print_tpm_option "$opt"; done
    fi
}

display_options() {
    local filter="${1:-}"
    print_header
    
    echo -e "${BOLD}${CYAN}╔═══════════════════════════════════════════════════════════════════════════╗${RESET}"
    echo -e "${BOLD}${CYAN}║  🌃 Tokyo Night Theme Options                                             ║${RESET}"
    echo -e "${BOLD}${CYAN}╚═══════════════════════════════════════════════════════════════════════════╝${RESET}"
    
    print_section "Theme Core Options" "$MAGENTA"
    for opt in "${THEME_OPTIONS[@]}"; do
        IFS='|' read -r option default possible description <<< "$opt"
        [[ -z "$filter" || "$option" == *"$filter"* || "$description" == *"$filter"* ]] && print_option "$option" "$default" "$possible" "$description"
    done
    
    # Discover and group plugin options
    local -A grouped_options=()
    while IFS= read -r option; do
        [[ -z "$option" ]] && continue
        local temp="${option#@powerkit_plugin_}" plugin_name="${temp%%_*}"
        grouped_options["$plugin_name"]+="$option "
    done < <(discover_plugin_options)
    
    for plugin_name in $(printf '%s\n' "${!grouped_options[@]}" | sort); do
        local has_visible=false
        for option in ${grouped_options[$plugin_name]}; do
            [[ -z "$filter" || "$option" == *"$filter"* ]] && {
                [[ "$has_visible" == "false" ]] && { print_section "Theme Plugin: ${plugin_name^}" "$MAGENTA"; has_visible=true; }
                print_option "$option" "" "" "Plugin option"
            }
        done
    done
    
    echo -e "\n\n${BOLD}${BLUE}╔═══════════════════════════════════════════════════════════════════════════╗${RESET}"
    echo -e "${BOLD}${BLUE}║  📦 Other TPM Plugins Options                                             ║${RESET}"
    echo -e "${BOLD}${BLUE}╚═══════════════════════════════════════════════════════════════════════════╝${RESET}"
    
    [[ -d "$TPM_PLUGINS_DIR" ]] && for plugin_dir in "$TPM_PLUGINS_DIR"/*/; do [[ -d "$plugin_dir" ]] && scan_tpm_plugin_options "$plugin_dir"; done
    
    echo -e "\n${DIM}Press 'q' to exit, '/' to search${RESET}\n"
}

[[ "${1:-}" == "--help" || "${1:-}" == "-h" ]] && { echo "Usage: $0 [filter]"; exit 0; }
less --help 2>&1 | grep -q -- '--mouse' && display_options "${1:-}" | less -R --mouse || display_options "${1:-}" | less -R
