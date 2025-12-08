#!/usr/bin/env bash
# Helper: keybindings_viewer - Display all tmux keybindings grouped by plugin

set -euo pipefail

BOLD="${POWERKIT_ANSI_BOLD:-\033[1m}"
DIM="${POWERKIT_ANSI_DIM:-\033[2m}"
CYAN="${POWERKIT_ANSI_CYAN:-\033[36m}"
GREEN="${POWERKIT_ANSI_GREEN:-\033[32m}"
YELLOW="${POWERKIT_ANSI_YELLOW:-\033[33m}"
MAGENTA="${POWERKIT_ANSI_MAGENTA:-\033[35m}"
BLUE="${POWERKIT_ANSI_BLUE:-\033[34m}"
RESET="${POWERKIT_ANSI_RESET:-\033[0m}"

TPM_PLUGINS_DIR="${TMUX_PLUGIN_MANAGER_PATH:-$HOME/.tmux/plugins}"
[[ ! -d "$TPM_PLUGINS_DIR" && -d "$HOME/.config/tmux/plugins" ]] && TPM_PLUGINS_DIR="$HOME/.config/tmux/plugins"

print_header() {
    echo -e "\n${BOLD}${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo -e "${BOLD}${CYAN}  ⌨️  tmux Keybindings Reference${RESET}"
    echo -e "${BOLD}${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}\n"
    local prefix; prefix=$(tmux show-option -gqv prefix 2>/dev/null || echo "C-b")
    echo -e "${DIM}  Prefix: ${YELLOW}${prefix}${RESET}\n"
}

print_section() { echo -e "\n${BOLD}${2:-$MAGENTA}▸ ${1}${RESET}\n${DIM}─────────────────────────────────────────────────────────────────────────────${RESET}"; }

format_key() { printf '%s' "${1//C-/Ctrl+}" | sed 's/M-/Alt+/g; s/S-/Shift+/g'; }

extract_plugin_from_path() {
    [[ "$1" == *"/plugins/"* ]] && echo "$1" | sed -n 's|.*/plugins/\([^/]*\)/.*|\1|p;q' || echo ""
}

print_keybindings() {
    print_section "Plugin Keybindings" "$CYAN"
    
    declare -A plugin_bindings
    declare -a builtin_bindings
    
    while IFS= read -r line; do
        [[ -z "$line" ]] && continue
        local key cmd plugin
        key=$(echo "$line" | awk '{print $4}')
        cmd=$(echo "$line" | cut -d' ' -f5-)
        plugin=$(extract_plugin_from_path "$cmd")
        key=$(format_key "$key")
        
        [[ -n "$plugin" ]] && plugin_bindings["$plugin"]+="${key}|${cmd}"$'\n' || builtin_bindings+=("${key}|${cmd}")
    done < <(tmux list-keys -T prefix 2>/dev/null)
    
    for plugin in $(printf '%s\n' "${!plugin_bindings[@]}" | sort); do
        echo -e "\n  ${BOLD}${BLUE}📦 ${plugin}${RESET}"
        echo -n "${plugin_bindings[$plugin]}" | while IFS='|' read -r key cmd; do
            [[ -z "$key" ]] && continue
            printf "    ${GREEN}%-15s${RESET} ${DIM}%s${RESET}\n" "$key" "$cmd"
        done
    done
    
    if [[ ${#builtin_bindings[@]} -gt 0 ]]; then
        print_section "tmux Built-in" "$MAGENTA"
        for binding in "${builtin_bindings[@]}"; do
            IFS='|' read -r key cmd <<< "$binding"
            printf "  ${GREEN}%-15s${RESET} ${DIM}%s${RESET}\n" "$key" "$cmd"
        done
    fi
}

print_root_bindings() {
    local bindings
    bindings=$(tmux list-keys -T root 2>/dev/null | head -20)
    [[ -z "$bindings" ]] && return
    
    print_section "Root Bindings (no prefix)" "$YELLOW"
    echo "$bindings" | while IFS= read -r line; do
        [[ -z "$line" ]] && continue
        local key cmd
        key=$(echo "$line" | awk '{print $4}')
        cmd=$(echo "$line" | cut -d' ' -f5-)
        printf "  ${GREEN}%-15s${RESET} ${DIM}%s${RESET}\n" "$(format_key "$key")" "$cmd"
    done
}

main() {
    print_header
    print_keybindings
    print_root_bindings
    echo -e "\n${DIM}Press 'q' to exit, '/' to search${RESET}\n"
}

main | less -R
