#!/usr/bin/env bash
# =============================================================================
# Plugin: yay
# Description: Display number of outdated AUR packages
# Dependencies: yay (AUR helper for Arch Linux)
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
plugin_yay_icon=$(get_tmux_option "@theme_plugin_yay_icon" "$PLUGIN_YAY_ICON")
# shellcheck disable=SC2034
plugin_yay_accent_color=$(get_tmux_option "@theme_plugin_yay_accent_color" "$PLUGIN_YAY_ACCENT_COLOR")
# shellcheck disable=SC2034
plugin_yay_accent_color_icon=$(get_tmux_option "@theme_plugin_yay_accent_color_icon" "$PLUGIN_YAY_ACCENT_COLOR_ICON")

# Cache TTL in seconds (default: 1800 seconds = 30 minutes)
# Package updates don't change frequently, so longer cache is appropriate
YAY_CACHE_TTL=$(get_tmux_option "@theme_plugin_yay_cache_ttl" "$PLUGIN_YAY_CACHE_TTL")
YAY_CACHE_KEY="yay"

export plugin_yay_icon plugin_yay_accent_color plugin_yay_accent_color_icon

# =============================================================================
# Helper Functions
# =============================================================================

# -----------------------------------------------------------------------------
# Check if yay is available
# Returns: 0 if available, 1 otherwise
# -----------------------------------------------------------------------------
yay_is_available() {
    command -v yay &>/dev/null
}

# -----------------------------------------------------------------------------
# Count outdated packages
# Returns: Number of outdated packages
# -----------------------------------------------------------------------------
yay_count_outdated() {
    local outdated_packages
    local count

    # Use 'yay -Qu' to list packages that need updating
    # The || true ensures we don't fail if no updates are available
    outdated_packages=$(yay -Qu 2>/dev/null || true)

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
# Returns: Formatted status string (empty if no updates)
# -----------------------------------------------------------------------------
yay_format_output() {
    local count="$1"

    # Return empty if no updates (conditional plugin won't render)
    if [[ "$count" -eq 0 ]]; then
        return 0
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
    # Check dependency - fail silently if yay is not available
    if ! yay_is_available; then
        return 0
    fi

    # Try to get from cache first
    local cached_value
    if cached_value=$(cache_get "$YAY_CACHE_KEY" "$YAY_CACHE_TTL"); then
        printf '%s' "$cached_value"
        return 0
    fi

    # Fetch fresh data
    local count result
    count=$(yay_count_outdated)
    result=$(yay_format_output "$count")

    # Update cache and output result
    cache_set "$YAY_CACHE_KEY" "$result"
    printf '%s' "$result"
}

# Only run if executed directly (not sourced)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    load_plugin
fi
