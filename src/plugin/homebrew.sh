#!/usr/bin/env bash
# =============================================================================
# Plugin: homebrew
# Description: Display number of outdated Homebrew packages
# Dependencies: brew (Homebrew package manager for macOS/Linux)
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
plugin_homebrew_icon=$(get_tmux_option "@theme_plugin_homebrew_icon" " ")
# shellcheck disable=SC2034
plugin_homebrew_accent_color=$(get_tmux_option "@theme_plugin_homebrew_accent_color" "blue7")
# shellcheck disable=SC2034
plugin_homebrew_accent_color_icon=$(get_tmux_option "@theme_plugin_homebrew_accent_color_icon" "blue0")

# Plugin-specific options
plugin_homebrew_options=$(get_tmux_option "@theme_plugin_homebrew_additional_options" "--greedy")

# Cache TTL in seconds (default: 1800 seconds = 30 minutes)
# Package updates don't change frequently, so longer cache is appropriate
HOMEBREW_CACHE_TTL=$(get_tmux_option "@theme_plugin_homebrew_cache_ttl" "1800")
HOMEBREW_CACHE_KEY="homebrew"

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
# Count outdated packages
# Returns: Number of outdated packages
# -----------------------------------------------------------------------------
homebrew_count_outdated() {
    local outdated_packages
    local count

    # Use 'brew outdated' to list packages that need updating
    # shellcheck disable=SC2086
    outdated_packages=$(brew outdated $plugin_homebrew_options 2>/dev/null || true)

    if [[ -z "$outdated_packages" ]]; then
        printf '0'
        return
    fi

    # Count non-empty lines
    count=$(printf '%s' "$outdated_packages" | grep -c . || printf '0')
    printf '%s' "$count"
}

# -----------------------------------------------------------------------------
# Format the output message
# Arguments:
#   $1 - Number of outdated packages
# Returns: Formatted status string
# -----------------------------------------------------------------------------
homebrew_format_output() {
    local count="$1"

    if [[ "$count" -eq 0 ]]; then
        printf 'All updated'
    elif [[ "$count" -eq 1 ]]; then
        printf '1 update'
    else
        printf '%s updates' "$count"
    fi
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

    # Fetch fresh data
    local count result
    count=$(homebrew_count_outdated)
    result=$(homebrew_format_output "$count")

    # Update cache and output result
    cache_set "$HOMEBREW_CACHE_KEY" "$result"
    printf '%s' "$result"
}

load_plugin
