#!/usr/bin/env bash
# =============================================================================
# Plugin: docker
# Description: Display number of running Docker containers
# Dependencies: docker
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
plugin_docker_icon=$(get_tmux_option "@theme_plugin_docker_icon" " ")
# shellcheck disable=SC2034
plugin_docker_accent_color=$(get_tmux_option "@theme_plugin_docker_accent_color" "blue7")
# shellcheck disable=SC2034
plugin_docker_accent_color_icon=$(get_tmux_option "@theme_plugin_docker_accent_color_icon" "blue0")

# Cache TTL in seconds
CACHE_TTL=10
CACHE_KEY="docker"

export plugin_docker_icon plugin_docker_accent_color plugin_docker_accent_color_icon

# =============================================================================
# Docker Functions
# =============================================================================

get_docker_info() {
    # Check if docker is available
    command -v docker &>/dev/null || return
    
    # Check if docker daemon is running  
    docker info &>/dev/null || return
    
    local running stopped
    running=$(docker ps -q 2>/dev/null | wc -l | tr -d ' ')
    stopped=$(docker ps -aq --filter "status=exited" 2>/dev/null | wc -l | tr -d ' ')
    
    # Only show if there are containers
    [[ "$running" -eq 0 && "$stopped" -eq 0 ]] && return
    
    local output=""
    [[ "$running" -gt 0 ]] && output="${running}"
    [[ "$stopped" -gt 0 ]] && output+=" ⏹${stopped}"
    
    echo -n "${output# }"
}

# =============================================================================
# Main Plugin Logic
# =============================================================================

load_plugin() {
    # Check cache first
    local cached_value
    if cached_value=$(cache_get "$CACHE_KEY" "$CACHE_TTL"); then
        printf '%s' "$cached_value"
        return
    fi

    local result
    result=$(get_docker_info) || result=""

    # Only cache non-empty results
    if [[ -n "$result" ]]; then
        cache_set "$CACHE_KEY" "$result"
    fi
    
    printf '%s' "$result"
}

# Only run if executed directly (not sourced)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    load_plugin
fi
