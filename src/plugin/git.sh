#!/usr/bin/env bash
# =============================================================================
# Plugin: git
# Description: Display current git branch and status
# Dependencies: git
# =============================================================================

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck source=src/defaults.sh
. "$ROOT_DIR/../defaults.sh"
# shellcheck source=src/utils.sh
. "$ROOT_DIR/../utils.sh"
# shellcheck source=src/cache.sh
. "$ROOT_DIR/../cache.sh"

# =============================================================================
# Plugin Configuration
# =============================================================================

# shellcheck disable=SC2034
plugin_git_icon=$(get_tmux_option "@theme_plugin_git_icon" "$PLUGIN_GIT_ICON")
# shellcheck disable=SC2034
plugin_git_accent_color=$(get_tmux_option "@theme_plugin_git_accent_color" "$PLUGIN_GIT_ACCENT_COLOR")
# shellcheck disable=SC2034
plugin_git_accent_color_icon=$(get_tmux_option "@theme_plugin_git_accent_color_icon" "$PLUGIN_GIT_ACCENT_COLOR_ICON")

# Colors for when there are changes in the active branch
# shellcheck disable=SC2034
plugin_git_modified_accent_color=$(get_tmux_option "@theme_plugin_git_modified_accent_color" "$PLUGIN_GIT_MODIFIED_ACCENT_COLOR")
# shellcheck disable=SC2034
plugin_git_modified_accent_color_icon=$(get_tmux_option "@theme_plugin_git_modified_accent_color_icon" "$PLUGIN_GIT_MODIFIED_ACCENT_COLOR_ICON")

# Cache TTL in seconds (default: 5 seconds - short TTL for git status responsiveness)
CACHE_TTL=$(get_tmux_option "@theme_plugin_git_cache_ttl" "$PLUGIN_GIT_CACHE_TTL")

export plugin_git_icon plugin_git_accent_color plugin_git_accent_color_icon plugin_git_modified_accent_color plugin_git_modified_accent_color_icon

# =============================================================================
# Git Functions
# =============================================================================

get_git_info() {
    local pane_path
    pane_path="$(tmux display-message -p '#{pane_current_path}')"
    
    [[ -z "$pane_path" || ! -d "$pane_path" ]] && return
    
    # Use subshell to avoid changing main shell's directory
    (
        cd "$pane_path" 2>/dev/null || return
        
        # Check if we're in a git repo (fastest way)
        git rev-parse --is-inside-work-tree &>/dev/null || return
        
        # Get branch and status in single efficient call
        local git_info has_changes
        git_info=$(git status --porcelain=v1 --branch 2>/dev/null | awk '
            NR==1 {
                # Parse branch line: ## branch_name [origin/branch_name [ahead N, behind M]]
                gsub(/^## /, "")
                gsub(/\.\.\..*/, "")
                branch = $0
            }
            NR>1 {
                # Count file status
                status = substr($0, 1, 2)
                if (status == "??") untracked++
                else if (status != "  ") changed++
                has_changes = 1
            }
            END {
                if (branch) {
                    result = branch
                    if (changed > 0) result = result " ~" changed
                    if (untracked > 0) result = result " +" untracked
                    # Add marker for changes detection
                    if (has_changes) result = "MODIFIED:" result
                    print result
                }
            }
        ')
        
        printf '%s' "$git_info"
    )

}

# =============================================================================
# Plugin Interface Implementation
# =============================================================================

# Function to inform the plugin type to the renderer
plugin_get_type() {
    printf 'conditional'
}

# Function to provide dynamic display information
# This is called by the renderer to get color overrides based on content
plugin_get_display_info() {
    local content="$1"
    
    # Check if content indicates modifications (starts with MODIFIED:)
    if [[ "$content" == MODIFIED:* ]]; then
        # Override colors to use yellow/orange for modifications
        local modified_accent modified_accent_icon
        modified_accent=$(get_tmux_option "@theme_plugin_git_modified_accent_color" "$PLUGIN_GIT_MODIFIED_ACCENT_COLOR")
        modified_accent_icon=$(get_tmux_option "@theme_plugin_git_modified_accent_color_icon" "$PLUGIN_GIT_MODIFIED_ACCENT_COLOR_ICON")
        
        printf '1:%s:%s:' "$modified_accent" "$modified_accent_icon"
    else
        # Use default colors
        printf '1:::'
    fi
}

# =============================================================================
# Main Plugin Logic
# =============================================================================

load_plugin() {
    # Generate unique cache key based on pane path using hash to handle long/special character paths
    local pane_path cache_key path_hash
    pane_path="$(tmux display-message -p '#{pane_current_path}' 2>/dev/null)"
    # Use md5sum (Linux) or md5 (BSD/macOS) for portable hashing
    if command -v md5sum &>/dev/null; then
        path_hash=$(printf '%s' "$pane_path" | md5sum | cut -d' ' -f1)
    elif command -v md5 &>/dev/null; then
        path_hash=$(printf '%s' "$pane_path" | md5 -q)
    else
        # Fallback: sanitize path by replacing non-alphanumeric chars with underscore
        path_hash="${pane_path//[^a-zA-Z0-9]/_}"
    fi
    cache_key="git_${path_hash}"
    
    # Check cache first
    local cached_value
    if cached_value=$(cache_get "$cache_key" "$CACHE_TTL"); then
        # Return cached content with MODIFIED: prefix intact for renderer
        printf '%s' "$cached_value"
        return 0
    fi
    
    local result
    result=$(get_git_info)
    
    # Cache the result (even if empty)
    cache_set "$cache_key" "$result"
    
    # Return result with MODIFIED: prefix intact for renderer
    printf '%s' "$result"
    return 0
}

# Only run if executed directly (not sourced)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    load_plugin
fi
