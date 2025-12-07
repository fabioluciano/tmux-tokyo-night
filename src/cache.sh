#!/usr/bin/env bash
# =============================================================================
# PowerKit Cache System - KISS/DRY Version
# =============================================================================

# Source guard
[[ -n "${_POWERKIT_CACHE_LOADED:-}" ]] && return 0
_POWERKIT_CACHE_LOADED=1

# Cache directory
CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/tmux-tokyo-night"

# OS detection for stat command (reuse from utils.sh if available)
_CACHE_IS_MACOS=""
if [[ -n "${_CACHED_OS:-}" ]]; then
    [[ "$_CACHED_OS" == "Darwin" ]] && _CACHE_IS_MACOS="1"
else
    [[ "$(uname -s)" == "Darwin" ]] && _CACHE_IS_MACOS="1"
fi

# Initialize cache directory (once per session)
_CACHE_INIT=""
cache_init() {
    [[ -n "$_CACHE_INIT" ]] && return
    [[ -d "$CACHE_DIR" ]] || mkdir -p "$CACHE_DIR"
    _CACHE_INIT=1
}

# Check if cache is valid
# Usage: cache_is_valid <key> <ttl_seconds>
cache_is_valid() {
    local cache_file="${CACHE_DIR}/${1}.cache"
    local ttl_seconds="$2"
    
    [[ -f "$cache_file" ]] || return 1
    
    local file_mtime current_time
    current_time=$(date +%s)
    
    if [[ -n "$_CACHE_IS_MACOS" ]]; then
        file_mtime=$(stat -f "%m" "$cache_file" 2>/dev/null) || return 1
    else
        file_mtime=$(stat -c "%Y" "$cache_file" 2>/dev/null) || return 1
    fi
    
    (( (current_time - file_mtime) < ttl_seconds ))
}

# Get cached value
# Usage: cache_get <key> <ttl_seconds>
cache_get() {
    local cache_file="${CACHE_DIR}/${1}.cache"
    local ttl_seconds="$2"
    
    cache_init
    
    if cache_is_valid "$1" "$ttl_seconds" && [[ -r "$cache_file" ]]; then
        printf '%s' "$(<"$cache_file")"
        return 0
    fi
    return 1
}

# Store value in cache
# Usage: cache_set <key> <value>
cache_set() {
    cache_init
    printf '%s' "$2" > "${CACHE_DIR}/${1}.cache"
}

# Invalidate cache
# Usage: cache_invalidate <key>
cache_invalidate() {
    local cache_file="${CACHE_DIR}/${1}.cache"
    [[ -f "$cache_file" ]] && rm -f "$cache_file"
}

# Clear all caches
cache_clear_all() {
    [[ -d "$CACHE_DIR" ]] && rm -rf "${CACHE_DIR:?}"/*
}

# Setup cache clear keybinding
setup_keybindings() {
    local clear_key
    clear_key=$(get_tmux_option "@powerkit_cache_clear_key" "${POWERKIT_PLUGIN_CACHE_CLEAR_KEY:-Q}")
    
    [[ -n "$clear_key" ]] && tmux bind-key "$clear_key" run-shell \
        "rm -rf '${CACHE_DIR:?}'/* 2>/dev/null; tmux refresh-client -S" \
        \\\; display "PowerKit cache cleared!"
}
