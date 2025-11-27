#!/usr/bin/env bash
# =============================================================================
# Cache System for tmux-tokyo-night plugins
# =============================================================================
#
# This module provides a simple file-based caching mechanism to improve
# performance of plugins that fetch external data (weather, media players, etc.)
#
# Usage:
#   source "$CURRENT_DIR/cache.sh"
#   
#   # Check if cache is valid and get cached value
#   if cached_value=$(cache_get "plugin_name" "$ttl_seconds"); then
#       echo "$cached_value"
#   else
#       # Fetch new data
#       new_value=$(fetch_data)
#       cache_set "plugin_name" "$new_value"
#       echo "$new_value"
#   fi
#
# =============================================================================

# Source guard - prevent multiple sourcing
# shellcheck disable=SC2317
if [[ -n "${_TMUX_TOKYO_NIGHT_CACHE_LOADED:-}" ]]; then
    return 0 2>/dev/null || exit 0
fi
_TMUX_TOKYO_NIGHT_CACHE_LOADED=1

# Default cache directory (uses XDG_CACHE_HOME or fallback to ~/.cache)
CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/tmux-tokyo-night"

# Detect OS once for stat command compatibility (use utils.sh if available)
if [[ -z "$_CACHED_OS" ]]; then
    _CACHE_IS_MACOS=""
    [[ "$(uname)" == "Darwin" ]] && _CACHE_IS_MACOS="1"
else
    _CACHE_IS_MACOS=""
    [[ "$_CACHED_OS" == "Darwin" ]] && _CACHE_IS_MACOS="1"
fi

# Flag to track if cache directory has been initialized
_CACHE_DIR_INITIALIZED=""

# -----------------------------------------------------------------------------
# Ensures the cache directory exists (only runs once per session)
# -----------------------------------------------------------------------------
cache_init() {
    [[ -n "$_CACHE_DIR_INITIALIZED" ]] && return
    [[ -d "$CACHE_DIR" ]] || mkdir -p "$CACHE_DIR"
    _CACHE_DIR_INITIALIZED=1
}

# -----------------------------------------------------------------------------
# Get the cache file path for a given plugin
#
# Arguments:
#   $1 - Plugin name (used as cache file identifier)
#
# Output:
#   Path to the cache file
# -----------------------------------------------------------------------------
cache_file_path() {
    local plugin_name="$1"
    echo "${CACHE_DIR}/${plugin_name}.cache"
}

# -----------------------------------------------------------------------------
# Check if cache exists and is still valid (not expired)
#
# Arguments:
#   $1 - Plugin name
#   $2 - TTL (Time To Live) in seconds
#
# Returns:
#   0 if cache is valid, 1 otherwise
# -----------------------------------------------------------------------------
cache_is_valid() {
    local plugin_name="$1"
    local ttl_seconds="$2"
    local cache_file="${CACHE_DIR}/${plugin_name}.cache"
    
    # Check if cache file exists
    [[ -f "$cache_file" ]] || return 1
    
    # Get file modification time (OS-specific)
    local file_mtime
    if [[ -n "$_CACHE_IS_MACOS" ]]; then
        file_mtime=$(stat -f "%m" "$cache_file" 2>/dev/null) || return 1
    else
        file_mtime=$(stat -c "%Y" "$cache_file" 2>/dev/null) || return 1
    fi
    
    # Check if cache has expired
    local current_time
    current_time=$(date +%s)
    (( (current_time - file_mtime) < ttl_seconds ))
}

# -----------------------------------------------------------------------------
# Get cached value if valid
#
# Arguments:
#   $1 - Plugin name
#   $2 - TTL (Time To Live) in seconds
#
# Output:
#   Cached value if valid
#
# Returns:
#   0 if cache hit and value returned, 1 if cache miss
# -----------------------------------------------------------------------------
cache_get() {
    local plugin_name="$1"
    local ttl_seconds="$2"
    local cache_file="${CACHE_DIR}/${plugin_name}.cache"
    
    cache_init
    
    if cache_is_valid "$plugin_name" "$ttl_seconds"; then
        cat "$cache_file"
        return 0
    fi
    
    return 1
}

# -----------------------------------------------------------------------------
# Store value in cache
#
# Arguments:
#   $1 - Plugin name
#   $2 - Value to cache
# -----------------------------------------------------------------------------
cache_set() {
    local plugin_name="$1"
    local value="$2"
    
    cache_init
    printf '%s' "$value" > "${CACHE_DIR}/${plugin_name}.cache"
}

# -----------------------------------------------------------------------------
# Invalidate (delete) cache for a plugin
#
# Arguments:
#   $1 - Plugin name
# -----------------------------------------------------------------------------
cache_invalidate() {
    local cache_file="${CACHE_DIR}/${1}.cache"
    [[ -f "$cache_file" ]] && rm -f "$cache_file"
}

# -----------------------------------------------------------------------------
# Clear all cache files
# -----------------------------------------------------------------------------
cache_clear_all() {
    [[ -d "$CACHE_DIR" ]] && rm -rf "${CACHE_DIR:?}"/*
}

# -----------------------------------------------------------------------------
# Get remaining TTL for a cached value
#
# Arguments:
#   $1 - Plugin name
#   $2 - Original TTL in seconds
#
# Output:
#   Remaining seconds until cache expires, or 0 if expired/missing
# -----------------------------------------------------------------------------
cache_remaining_ttl() {
    local plugin_name="$1"
    local ttl_seconds="$2"
    local cache_file="${CACHE_DIR}/${plugin_name}.cache"
    
    [[ -f "$cache_file" ]] || { printf '0'; return; }
    
    local file_mtime
    if [[ -n "$_CACHE_IS_MACOS" ]]; then
        file_mtime=$(stat -f "%m" "$cache_file" 2>/dev/null) || { printf '0'; return; }
    else
        file_mtime=$(stat -c "%Y" "$cache_file" 2>/dev/null) || { printf '0'; return; }
    fi
    
    local current_time remaining
    current_time=$(date +%s)
    remaining=$((ttl_seconds - (current_time - file_mtime)))
    
    (( remaining > 0 )) && printf '%d' "$remaining" || printf '0'
}
