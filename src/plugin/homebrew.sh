#!/usr/bin/env bash
# =============================================================================
# Plugin: homebrew
# Description: Display number of outdated Homebrew packages
# Dependencies: brew (Homebrew package manager for macOS/Linux)
#
# PERFORMANCE: This plugin uses background refresh to avoid blocking.
# On first run or cache miss, it triggers a background job to fetch
# updates and returns the last known value (or empty). Subsequent
# calls use the cached value until TTL expires.
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
plugin_homebrew_icon=$(get_tmux_option "@theme_plugin_homebrew_icon" "$PLUGIN_HOMEBREW_ICON")
# shellcheck disable=SC2034
plugin_homebrew_accent_color=$(get_tmux_option "@theme_plugin_homebrew_accent_color" "$PLUGIN_HOMEBREW_ACCENT_COLOR")
# shellcheck disable=SC2034
plugin_homebrew_accent_color_icon=$(get_tmux_option "@theme_plugin_homebrew_accent_color_icon" "$PLUGIN_HOMEBREW_ACCENT_COLOR_ICON")

# Plugin-specific options
plugin_homebrew_options=$(get_tmux_option "@theme_plugin_homebrew_additional_options" "$PLUGIN_HOMEBREW_ADDITIONAL_OPTIONS")

# Cache TTL in seconds (default: 1800 seconds = 30 minutes)
# Package updates don't change frequently, so longer cache is appropriate
HOMEBREW_CACHE_TTL=$(get_tmux_option "@theme_plugin_homebrew_cache_ttl" "$PLUGIN_HOMEBREW_CACHE_TTL")
HOMEBREW_CACHE_KEY="homebrew"
HOMEBREW_LOCK_FILE="${CACHE_DIR:-$HOME/.cache/tmux-tokyo-night}/homebrew_updating.lock"

export plugin_homebrew_icon plugin_homebrew_accent_color plugin_homebrew_accent_color_icon

# =============================================================================
# Helper Functions
# =============================================================================

# -----------------------------------------------------------------------------
# Check if brew is available
# Returns: 0 if available, 1 otherwise
# -----------------------------------------------------------------------------
homebrew_is_available() {
    command -v brew &>/dev/null
}

# -----------------------------------------------------------------------------
# Check if background update is running
# Returns: 0 if running, 1 otherwise
# -----------------------------------------------------------------------------
homebrew_is_updating() {
    # Check if lock file exists and is recent (less than 5 minutes old)
    if [[ -f "$HOMEBREW_LOCK_FILE" ]]; then
        local lock_age
        lock_age=$(( $(date +%s) - $(stat -f %m "$HOMEBREW_LOCK_FILE" 2>/dev/null || stat -c %Y "$HOMEBREW_LOCK_FILE" 2>/dev/null || echo 0) ))
        if [[ $lock_age -lt 300 ]]; then
            return 0
        else
            # Stale lock, remove it
            rm -f "$HOMEBREW_LOCK_FILE"
        fi
    fi
    return 1
}

# -----------------------------------------------------------------------------
# Run background update
# Fetches outdated packages and updates cache
# -----------------------------------------------------------------------------
homebrew_background_update() {
    # Create lock file
    mkdir -p "$(dirname "$HOMEBREW_LOCK_FILE")"
    touch "$HOMEBREW_LOCK_FILE"
    
    # Run brew outdated in background
    (
        local outdated_packages count result
        
        # shellcheck disable=SC2086
        outdated_packages=$(brew outdated $plugin_homebrew_options 2>/dev/null || true)
        
        if [[ -z "$outdated_packages" ]]; then
            count=0
        else
            count=$(printf '%s' "$outdated_packages" | grep -c . || printf '0')
        fi
        
        # Format result
        if [[ "$count" -eq 0 ]]; then
            result=""
        elif [[ "$count" -eq 1 ]]; then
            result="1 update"
        else
            result="$count updates"
        fi
        
        # Update cache
        cache_set "$HOMEBREW_CACHE_KEY" "$result"
        
        # Remove lock file
        rm -f "$HOMEBREW_LOCK_FILE"
    ) &>/dev/null &
    
    disown 2>/dev/null || true
}

# =============================================================================
# Main Plugin Logic
# =============================================================================

load_plugin() {
    # Check dependency - fail silently if brew is not available
    if ! homebrew_is_available; then
        return 0
    fi

    # Try to get from cache first
    local cached_value
    if cached_value=$(cache_get "$HOMEBREW_CACHE_KEY" "$HOMEBREW_CACHE_TTL"); then
        printf '%s' "$cached_value"
        return 0
    fi
    
    # Cache miss - check if already updating
    if homebrew_is_updating; then
        # Return last known value (even if expired) or empty
        cached_value=$(cache_get "$HOMEBREW_CACHE_KEY" "86400" 2>/dev/null || echo "")
        printf '%s' "$cached_value"
        return 0
    fi
    
    # Start background update
    homebrew_background_update
    
    # Return last known value or empty (first run will show nothing)
    cached_value=$(cache_get "$HOMEBREW_CACHE_KEY" "86400" 2>/dev/null || echo "")
    printf '%s' "$cached_value"
}

# Only run if executed directly (not sourced)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    load_plugin
fi
