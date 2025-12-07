#!/usr/bin/env bash
# =============================================================================
# tmux Keybindings Viewer
# Displays all tmux keybindings dynamically grouped by plugin
# 100% dynamic - no hardcoded plugin lists
# =============================================================================

set -euo pipefail

# Colors for output (from defaults.sh)
BOLD="$POWERKIT_ANSI_BOLD"
DIM="$POWERKIT_ANSI_DIM"
CYAN="$POWERKIT_ANSI_CYAN"
GREEN="$POWERKIT_ANSI_GREEN"
YELLOW="$POWERKIT_ANSI_YELLOW"
MAGENTA="$POWERKIT_ANSI_MAGENTA"
BLUE="$POWERKIT_ANSI_BLUE"
RESET="$POWERKIT_ANSI_RESET"

# TPM plugins directory
TPM_PLUGINS_DIR="${TMUX_PLUGIN_MANAGER_PATH:-$HOME/.tmux/plugins}"
if [[ ! -d "$TPM_PLUGINS_DIR" ]] && [[ -d "$HOME/.config/tmux/plugins" ]]; then
    TPM_PLUGINS_DIR="$HOME/.config/tmux/plugins"
fi

# =============================================================================
# Helper Functions
# =============================================================================

print_header() {
    echo -e "\n${BOLD}${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo -e "${BOLD}${CYAN}  ⌨️  tmux Keybindings Reference${RESET}"
    echo -e "${BOLD}${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}\n"
    
    local prefix
    prefix=$(tmux show-option -gqv prefix 2>/dev/null || echo "C-b")
    echo -e "${DIM}  Prefix: ${YELLOW}${prefix}${RESET}\n"
}

print_section() {
    local title="$1"
    local color="${2:-$MAGENTA}"
    echo -e "\n${BOLD}${color}▸ ${title}${RESET}"
    echo -e "${DIM}─────────────────────────────────────────────────────────────────────────────${RESET}"
}

format_key() {
    local key="$1"
    key="${key//C-/Ctrl+}"
    key="${key//M-/Alt+}"
    key="${key//S-/Shift+}"
    printf '%s' "$key"
}

# Extract plugin name from command path (e.g., /path/to/plugins/extrakto/script.sh -> extrakto)
extract_plugin_from_path() {
    local cmd="$1"
    local plugin_name=""
    
    # Check if command contains plugins directory path
    if [[ "$cmd" == *"/plugins/"* ]]; then
        # Extract: /path/plugins/PLUGIN_NAME/...
        plugin_name=$(echo "$cmd" | sed -n 's|.*/plugins/\([^/]*\)/.*|\1|p;q')
    fi
    
    printf '%s' "$plugin_name"
}

# =============================================================================
# Main Display
# =============================================================================

print_keybindings() {
    print_section "Plugin Keybindings" "$CYAN"
    
    # Get all bindings and group by detected plugin
    declare -A plugin_bindings
    declare -a builtin_bindings
    
    while IFS= read -r line; do
        [[ -z "$line" ]] && continue
        
        local key cmd plugin
        key=$(echo "$line" | awk '{print $4}')
        cmd=$(echo "$line" | cut -d' ' -f5-)
        
        # Try to extract plugin from path in command
        plugin=$(extract_plugin_from_path "$cmd")
        
        key=$(format_key "$key")
        
        if [[ -n "$plugin" ]]; then
            plugin_bindings["$plugin"]+="${key}|${cmd}"$'\n'
        else
            builtin_bindings+=("${key}|${cmd}")
        fi
    done < <(tmux list-keys -T prefix 2>/dev/null)
    
    # Print plugin bindings (sorted by plugin name)
    for plugin in $(printf '%s\n' "${!plugin_bindings[@]}" | sort); do
        echo -e "\n  ${BOLD}${BLUE}📦 ${plugin}${RESET}"
        echo -n "${plugin_bindings[$plugin]}" | while IFS='|' read -r key cmd; do
            [[ -z "$key" ]] && continue
            printf "    ${GREEN}%-${POWERKIT_FORMAT_KEY_WIDTH}s${RESET} ${DIM}%s${RESET}\n" "$key" "$cmd"
        done
    done
    
    # Print built-in bindings
    if [[ ${#builtin_bindings[@]} -gt 0 ]]; then
        print_section "tmux Built-in" "$MAGENTA"
        for binding in "${builtin_bindings[@]}"; do
            IFS='|' read -r key cmd <<< "$binding"
            printf "  ${GREEN}%-${POWERKIT_FORMAT_KEY_WIDTH}s${RESET} ${DIM}%s${RESET}\n" "$key" "$cmd"
        done
    fi
}

print_root_bindings() {
    local bindings
    bindings=$(tmux list-keys -T root 2>/dev/null | head -"$POWERKIT_LIMIT_KEYBINDINGS_ROOT")
    
    [[ -z "$bindings" ]] && return
    
    print_section "Root Bindings (no prefix)" "$YELLOW"
    
    echo "$bindings" | while IFS= read -r line; do
        [[ -z "$line" ]] && continue
        local key cmd
        key=$(echo "$line" | awk '{print $4}')
        cmd=$(echo "$line" | cut -d' ' -f5-)
        key=$(format_key "$key")
        printf "  ${GREEN}%-15s${RESET} ${DIM}%s${RESET}\n" "$key" "$cmd"
    done
}

# =============================================================================
# Main
# =============================================================================

main() {
    print_header
    print_keybindings
    print_root_bindings
    echo -e "\n${DIM}Press 'q' to exit, '/' to search${RESET}\n"
}

main | less -R

