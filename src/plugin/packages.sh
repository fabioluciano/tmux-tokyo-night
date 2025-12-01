#!/usr/bin/env bash
# =============================================================================
# Plugin: packages
# Description: Display number of outdated packages (unified package manager plugin)
# 
# Automatically detects and uses the system's package manager:
#   - brew (macOS/Linux): Homebrew
#   - yay (Arch Linux): AUR helper
#   - apt (Debian/Ubuntu): APT package manager
#   - dnf (Fedora/RHEL): DNF package manager
#   - pacman (Arch Linux): Pacman package manager
#
# This plugin replaces: homebrew, yay
# =============================================================================

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck source=src/defaults.sh
. "$ROOT_DIR/../defaults.sh"
# shellcheck source=src/utils.sh
. "$ROOT_DIR/../utils.sh"
# shellcheck source=src/cache.sh
. "$ROOT_DIR/../cache.sh"
# shellcheck source=src/plugin_interface.sh
. "$ROOT_DIR/../plugin_interface.sh"

# =============================================================================
# Plugin Configuration
# =============================================================================

# shellcheck disable=SC2034
plugin_packages_icon=$(get_tmux_option "@theme_plugin_packages_icon" "$PLUGIN_PACKAGES_ICON")
# shellcheck disable=SC2034
plugin_packages_accent_color=$(get_tmux_option "@theme_plugin_packages_accent_color" "$PLUGIN_PACKAGES_ACCENT_COLOR")
# shellcheck disable=SC2034
plugin_packages_accent_color_icon=$(get_tmux_option "@theme_plugin_packages_accent_color_icon" "$PLUGIN_PACKAGES_ACCENT_COLOR_ICON")

# Preferred backend: auto, brew, yay, apt, dnf, pacman
plugin_packages_backend=$(get_tmux_option "@theme_plugin_packages_backend" "$PLUGIN_PACKAGES_BACKEND")

# Additional options for specific backends
plugin_packages_brew_options=$(get_tmux_option "@theme_plugin_packages_brew_options" "$PLUGIN_PACKAGES_BREW_OPTIONS")

# Cache TTL in seconds (default: 1800 = 30 minutes)
CACHE_TTL=$(get_tmux_option "@theme_plugin_packages_cache_ttl" "$PLUGIN_PACKAGES_CACHE_TTL")
CACHE_KEY="packages"
LOCK_DIR="${CACHE_DIR:-$HOME/.cache/tmux-tokyo-night}/packages_updating.lock"

export plugin_packages_icon plugin_packages_accent_color plugin_packages_accent_color_icon

# =============================================================================
# Backend Detection
# =============================================================================

# Cache detected backend (avoid repeated command -v calls)
_DETECTED_PACKAGE_MANAGER=""

# Detect best available package manager
detect_backend() {
    # Return cached result if already detected
    [[ -n "$_DETECTED_PACKAGE_MANAGER" ]] && echo "$_DETECTED_PACKAGE_MANAGER" && return
    
    case "$plugin_packages_backend" in
        brew)
            command -v brew &>/dev/null && _DETECTED_PACKAGE_MANAGER="brew" && echo "brew" && return
            ;;
        yay)
            command -v yay &>/dev/null && _DETECTED_PACKAGE_MANAGER="yay" && echo "yay" && return
            ;;
        apt)
            command -v apt &>/dev/null && _DETECTED_PACKAGE_MANAGER="apt" && echo "apt" && return
            ;;
        dnf)
            command -v dnf &>/dev/null && _DETECTED_PACKAGE_MANAGER="dnf" && echo "dnf" && return
            ;;
        pacman)
            command -v pacman &>/dev/null && _DETECTED_PACKAGE_MANAGER="pacman" && echo "pacman" && return
            ;;
        auto|*)
            # Auto-detect based on system
            command -v brew &>/dev/null && _DETECTED_PACKAGE_MANAGER="brew" && echo "brew" && return
            command -v yay &>/dev/null && _DETECTED_PACKAGE_MANAGER="yay" && echo "yay" && return
            command -v dnf &>/dev/null && _DETECTED_PACKAGE_MANAGER="dnf" && echo "dnf" && return
            command -v apt &>/dev/null && _DETECTED_PACKAGE_MANAGER="apt" && echo "apt" && return
            command -v pacman &>/dev/null && _DETECTED_PACKAGE_MANAGER="pacman" && echo "pacman" && return
            ;;
    esac
    
    echo ""
}

# =============================================================================
# Helper Functions
# =============================================================================

# Check if background update is running
is_updating() {
    if [[ -d "$LOCK_DIR" ]]; then
        local lock_age current_time dir_mtime
        current_time=$(date +%s)
        
        if is_macos; then
            dir_mtime=$(stat -f %m "$LOCK_DIR" 2>/dev/null || echo 0)
        else
            dir_mtime=$(stat -c %Y "$LOCK_DIR" 2>/dev/null || echo 0)
        fi
        
        lock_age=$((current_time - dir_mtime))
        
        if [[ $lock_age -lt 300 ]]; then
            return 0
        else
            # Stale lock, remove it
            rmdir "$LOCK_DIR" 2>/dev/null
        fi
    fi
    return 1
}

# =============================================================================
# Backend Implementations
# =============================================================================

# -----------------------------------------------------------------------------
# Homebrew backend (macOS/Linux)
# -----------------------------------------------------------------------------
count_packages_brew() {
    local cached count
    
    # Try cache first
    cached=$(cache_get "$CACHE_KEY" "$CACHE_TTL" 2>/dev/null)
    
    # If cache valid or update running, return cached value
    if [[ -n "$cached" ]] || is_updating; then
        printf '%s' "${cached:-0}"
        return 0
    fi
    
    # Try to create lock atomically (mkdir is atomic)
    if ! mkdir "$LOCK_DIR" 2>/dev/null; then
        # Someone else got the lock, return cached
        printf '%s' "${cached:-0}"
        return 0
    fi
    
    # We got the lock, start background update
    (
        # Count outdated packages (single command)
        local outdated
        outdated=$(command brew outdated "$plugin_packages_brew_options" 2>/dev/null || echo "")
        
        if [[ -z "$outdated" ]]; then
            count=0
        else
            count=$(printf '%s' "$outdated" | command grep -c .)
        fi
        
        # Save to cache
        cache_set "$CACHE_KEY" "$count"
        
        rmdir "$LOCK_DIR" 2>/dev/null
    ) &>/dev/null &
    
    # Return old cached value or 0 while updating
    printf '%s' "${cached:-0}"
}

# -----------------------------------------------------------------------------
# Yay backend (Arch Linux AUR)
# -----------------------------------------------------------------------------
count_packages_yay() {
    local cached count outdated
    
    # Try cache first
    cached=$(cache_get "$CACHE_KEY" "$CACHE_TTL" 2>/dev/null)
    
    # If cache valid, return cached value
    if [[ -n "$cached" ]]; then
        printf '%s' "$cached"
        return 0
    fi
    
    # Get outdated packages
    outdated=$(command yay -Qu 2>/dev/null || echo "")
    
    if [[ -z "$outdated" ]]; then
        count=0
    else
        # Use wc -l which is faster than grep -c for line counting
        count=$(printf '%s' "$outdated" | command wc -l)
    fi
    
    # Cache result
    cache_set "$CACHE_KEY" "$count"
    printf '%s' "$count"
}

# -----------------------------------------------------------------------------
# APT backend (Debian/Ubuntu)
# -----------------------------------------------------------------------------
count_packages_apt() {
    local cached count
    
    # Try cache first
    cached=$(cache_get "$CACHE_KEY" "$CACHE_TTL" 2>/dev/null)
    
    # If cache valid or update running, return cached value
    if [[ -n "$cached" ]] || is_updating; then
        printf '%s' "${cached:-0}"
        return 0
    fi
    
    # Try to create lock atomically (mkdir is atomic)
    if ! mkdir "$LOCK_DIR" 2>/dev/null; then
        # Someone else got the lock, return cached
        printf '%s' "${cached:-0}"
        return 0
    fi
    
    # We got the lock, start background update
    (
        # Update package list, then count upgradable (more reliable than checking without update)
        command apt update &>/dev/null
        count=$(command apt list --upgradable 2>/dev/null | command grep -c upgradable)
        
        cache_set "$CACHE_KEY" "$count"
        rmdir "$LOCK_DIR" 2>/dev/null
    ) &>/dev/null &
    
    # Return old cached value or 0 while updating
    printf '%s' "${cached:-0}"
}

# -----------------------------------------------------------------------------
# DNF backend (Fedora/RHEL)
# -----------------------------------------------------------------------------
count_packages_dnf() {
    local cached count
    
    # Try cache first
    cached=$(cache_get "$CACHE_KEY" "$CACHE_TTL" 2>/dev/null)
    
    # If cache valid or update running, return cached value
    if [[ -n "$cached" ]] || is_updating; then
        printf '%s' "${cached:-0}"
        return 0
    fi
    
    # Try to create lock atomically (mkdir is atomic)
    if ! mkdir "$LOCK_DIR" 2>/dev/null; then
        # Someone else got the lock, return cached
        printf '%s' "${cached:-0}"
        return 0
    fi
    
    # We got the lock, start background update
    (
        # Check for updates
        count=$(command dnf check-update -q 2>/dev/null | command grep -c .)
        
        # dnf check-update lists packages, count lines
        if [[ "$count" -gt 0 ]]; then
            # Subtract header lines (usually 2-3 lines)
            count=$((count > 3 ? count - 3 : 0))
        fi
        
        cache_set "$CACHE_KEY" "$count"
        rmdir "$LOCK_DIR" 2>/dev/null
    ) &>/dev/null &
    
    # Return old cached value or 0 while updating
    printf '%s' "${cached:-0}"
}

# -----------------------------------------------------------------------------
# Pacman backend (Arch Linux)
# -----------------------------------------------------------------------------
count_packages_pacman() {
    local cached count
    
    # Try cache first
    cached=$(cache_get "$CACHE_KEY" "$CACHE_TTL" 2>/dev/null)
    
    # If cache valid, return cached value
    if [[ -n "$cached" ]]; then
        printf '%s' "$cached"
        return 0
    fi
    
    # Check for updates (use wc -l instead of grep -c)
    count=$(command pacman -Qu 2>/dev/null | command wc -l)
    
    # Cache result
    cache_set "$CACHE_KEY" "$count"
    printf '%s' "$count"
}

# =============================================================================
# Output Formatting
# =============================================================================

format_output() {
    local count="$1"
    
    # Return empty if no updates (plugin will be hidden)
    if [[ "$count" -eq 0 ]]; then
        return 0
    elif [[ "$count" -eq 1 ]]; then
        printf '1 update'
    else
        printf '%s updates' "$count"
    fi
}

# =============================================================================
# Plugin Interface Implementation
# =============================================================================

plugin_get_display_info() {
    local content="$1"
    local show="1"
    local accent=""
    local accent_icon=""
    local icon=""
    
    # Hide if no updates
    if [[ -z "$content" || "$content" == "0" || "$content" == "0 updates" ]]; then
        show="0"
    fi
    
    build_display_info "$show" "$accent" "$accent_icon" "$icon"
}

# =============================================================================
# Main Plugin Logic
# =============================================================================

load_plugin() {
    # Detect backend
    local backend
    backend=$(detect_backend)
    
    # No backend available
    [[ -z "$backend" ]] && return 0
    
    # Try cache first (except for fast backends like yay/pacman)
    if [[ "$backend" != "yay" && "$backend" != "pacman" ]]; then
        local cached_value
        if cached_value=$(cache_get "$CACHE_KEY" "$CACHE_TTL" 2>/dev/null); then
            format_output "$cached_value"
            return 0
        fi
    fi
    
    # Get count from appropriate backend
    local count=0
    case "$backend" in
        brew)
            count=$(count_packages_brew)
            ;;
        yay)
            count=$(count_packages_yay)
            ;;
        apt)
            count=$(count_packages_apt)
            ;;
        dnf)
            count=$(count_packages_dnf)
            ;;
        pacman)
            count=$(count_packages_pacman)
            ;;
    esac
    
    # Cache the count only for backends that don't cache themselves (yay, pacman)
    if [[ "$backend" == "yay" || "$backend" == "pacman" ]]; then
        cache_set "$CACHE_KEY" "$count"
    fi
    
    # Format and output
    format_output "$count"
}

# Only run if executed directly (not sourced)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    load_plugin
fi
