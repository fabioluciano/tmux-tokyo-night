#!/usr/bin/env bash
# =============================================================================
# Plugin: docker
# Description: Display number of running Docker containers
# Dependencies: docker
#
# PERFORMANCE: Uses single docker call and relies on cache heavily.
# docker info check is skipped - if docker ps fails, we assume daemon is down.
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
plugin_docker_icon=$(get_tmux_option "@theme_plugin_docker_icon" "$PLUGIN_DOCKER_ICON")
# shellcheck disable=SC2034
plugin_docker_accent_color=$(get_tmux_option "@theme_plugin_docker_accent_color" "$PLUGIN_DOCKER_ACCENT_COLOR")
# shellcheck disable=SC2034
plugin_docker_accent_color_icon=$(get_tmux_option "@theme_plugin_docker_accent_color_icon" "$PLUGIN_DOCKER_ACCENT_COLOR_ICON")

# Cache TTL in seconds (default: 10 seconds)
CACHE_TTL=$(get_tmux_option "@theme_plugin_docker_cache_ttl" "$PLUGIN_DOCKER_CACHE_TTL")
CACHE_KEY="docker"

export plugin_docker_icon plugin_docker_accent_color plugin_docker_accent_color_icon

# =============================================================================
# Docker Functions
# =============================================================================

get_docker_info() {
    # Check if docker is available
    command -v docker &>/dev/null || return
    
    # Single docker call to get both running and stopped counts
    # Skip 'docker info' check - if docker ps fails, daemon is down
    local states running=0 stopped=0
    
    # Use timeout to prevent hanging if docker is unresponsive
    states=$(timeout 2 docker ps -a --format '{{.State}}' 2>/dev/null) || return
    
    while IFS= read -r state; do
        [[ -z "$state" ]] && continue
        case "$state" in
            running) ((running++)) ;;
            exited|paused|restarting|dead|created|removing) ((stopped++)) ;;
        esac
    done <<< "$states"
    
    # Only show if there are containers
    [[ "$running" -eq 0 && "$stopped" -eq 0 ]] && return
    
    local output=""
    [[ "$running" -gt 0 ]] && output="${running}"
    [[ "$stopped" -gt 0 ]] && output+=" ⏹${stopped}"
    
    printf '%s' "${output# }"
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
