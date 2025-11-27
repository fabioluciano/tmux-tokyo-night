#!/usr/bin/env bash
# =============================================================================
# Plugin: git
# Description: Display current git branch and status
# Dependencies: git
# =============================================================================

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck source=src/utils.sh
. "$ROOT_DIR/../utils.sh"
# shellcheck source=src/cache.sh
. "$ROOT_DIR/../cache.sh"

# =============================================================================
# Plugin Configuration
# =============================================================================

# shellcheck disable=SC2034
plugin_git_icon=$(get_tmux_option "@theme_plugin_git_icon" " ")
# shellcheck disable=SC2034
plugin_git_accent_color=$(get_tmux_option "@theme_plugin_git_accent_color" "blue7")
# shellcheck disable=SC2034
plugin_git_accent_color_icon=$(get_tmux_option "@theme_plugin_git_accent_color_icon" "blue0")

# Cache TTL in seconds (default: 5 seconds - short TTL for git status responsiveness)
CACHE_TTL=$(get_tmux_option "@theme_plugin_git_cache_ttl" "5")

export plugin_git_icon plugin_git_accent_color plugin_git_accent_color_icon

# =============================================================================
# Git Functions
# =============================================================================

get_git_info() {
    local pane_path
    pane_path="$(tmux display-message -p '#{pane_current_path}')"
    
    [[ -z "$pane_path" || ! -d "$pane_path" ]] && return
    
    cd "$pane_path" 2>/dev/null || return
    
    # Check if we're in a git repo
    git rev-parse --git-dir &>/dev/null || return
    
    local branch
    branch=$(git symbolic-ref --short HEAD 2>/dev/null || \
             git rev-parse --short HEAD 2>/dev/null)
    
    [[ -z "$branch" ]] && return
    
    # Get status counts
    local status_output
    status_output=$(git status --porcelain 2>/dev/null)
    
    local changed=0 untracked=0
    while IFS= read -r line; do
        [[ -z "$line" ]] && continue
        if [[ "${line:0:2}" == "??" ]]; then
            ((untracked++))
        else
            ((changed++))
        fi
    done <<< "$status_output"
    
    # Build output
    local output="$branch"
    [[ $changed -gt 0 ]] && output+=" ~$changed"
    [[ $untracked -gt 0 ]] && output+=" +$untracked"
    
    printf '%s' "$output"
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
        printf '%s' "$cached_value"
        return 0
    fi
    
    local result
    result=$(get_git_info)
    
    # Cache the result (even if empty)
    cache_set "$cache_key" "$result"
    
    printf '%s' "$result"
    return 0
}

# Only run if executed directly (not sourced)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    load_plugin
fi
