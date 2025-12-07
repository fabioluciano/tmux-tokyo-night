#!/usr/bin/env bash
# =============================================================================
# PowerKit Utility Functions - KISS/DRY Version
# =============================================================================
# shellcheck disable=SC2034

# Source guard
[[ -n "${_POWERKIT_UTILS_LOADED:-}" ]] && return 0
_POWERKIT_UTILS_LOADED=1

CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$CURRENT_DIR/defaults.sh"

# =============================================================================
# OS Detection (cached)
# =============================================================================

_CACHED_OS="$(uname -s)"
is_macos() { [[ "$_CACHED_OS" == "Darwin" ]]; }
is_linux() { [[ "$_CACHED_OS" == "Linux" ]]; }

# =============================================================================
# Tmux Option Getter
# =============================================================================

get_tmux_option() {
    local option="$1"
    local default_value="$2"
    local value
    value=$(tmux show-option -gqv "$option" 2>/dev/null)
    printf '%s' "${value:-$default_value}"
}

# =============================================================================
# Theme Color System
# =============================================================================

declare -A POWERKIT_THEME_COLORS

# Load theme and populate POWERKIT_THEME_COLORS
load_powerkit_theme() {
    local theme_family="" theme_variant="" theme_dir="" theme_file=""
    
    # Check @powerkit_theme first (simple format)
    local powerkit_theme
    powerkit_theme=$(get_tmux_option "@powerkit_theme" "")
    
    if [[ -n "$powerkit_theme" ]]; then
        theme_family="$powerkit_theme"
        theme_dir="$CURRENT_DIR/themes/${theme_family}"
        
        # Auto-detect first variant
        if [[ -d "$theme_dir" ]]; then
            theme_variant=$(ls "$theme_dir"/*.sh 2>/dev/null | head -1 | xargs basename -s .sh 2>/dev/null || echo "")
        fi
    fi
    
    # Fallback to explicit family/variant
    [[ -z "$theme_family" ]] && theme_family=$(get_tmux_option "@powerkit_theme_family" "$POWERKIT_DEFAULT_THEME_FAMILY")
    [[ -z "$theme_variant" ]] && theme_variant=$(get_tmux_option "@powerkit_theme_variant" "$POWERKIT_DEFAULT_THEME_VARIANT")
    
    # Auto-detect variant if still empty
    if [[ -z "$theme_variant" ]]; then
        theme_dir="$CURRENT_DIR/themes/${theme_family}"
        [[ -d "$theme_dir" ]] && theme_variant=$(ls "$theme_dir"/*.sh 2>/dev/null | head -1 | xargs basename -s .sh 2>/dev/null || echo "")
    fi
    
    # Final fallback
    [[ -z "$theme_family" ]] && theme_family="tokyo-night"
    [[ -z "$theme_variant" ]] && theme_variant="night"
    
    # Load theme file
    theme_file="$CURRENT_DIR/themes/${theme_family}/${theme_variant}.sh"
    if [[ -f "$theme_file" ]]; then
        . "$theme_file"
        # Copy THEME_COLORS to POWERKIT_THEME_COLORS
        if declare -p THEME_COLORS &>/dev/null; then
            for key in "${!THEME_COLORS[@]}"; do
                POWERKIT_THEME_COLORS["$key"]="${THEME_COLORS[$key]}"
            done
        fi
    fi
}

# Get semantic color from theme
# Usage: get_powerkit_color "accent" [fallback]
get_powerkit_color() {
    local color_name="$1"
    local fallback="${2:-$color_name}"
    
    # Load theme if not loaded
    [[ ${#POWERKIT_THEME_COLORS[@]} -eq 0 ]] && load_powerkit_theme
    
    # Return theme color or fallback
    printf '%s' "${POWERKIT_THEME_COLORS[$color_name]:-$fallback}"
}

# =============================================================================
# OS Icon Detection
# =============================================================================

get_os_icon() {
    local icon
    
    if is_macos; then
        icon=$'\uf302'
    elif is_linux; then
        local distro_id
        distro_id=$(awk -F'=' '/^ID=/ {gsub(/"/, "", $2); print $2; exit}' /etc/os-release 2>/dev/null)
        case "$distro_id" in
            ubuntu)      icon=$'\uf31b' ;;
            debian)      icon=$'\uf306' ;;
            fedora)      icon=$'\uf30a' ;;
            arch)        icon=$'\uf303' ;;
            manjaro)     icon=$'\uf312' ;;
            centos|rhel) icon=$'\uf304' ;;
            opensuse*)   icon=$'\uf314' ;;
            alpine)      icon=$'\uf300' ;;
            gentoo)      icon=$'\uf30d' ;;
            linuxmint)   icon=$'\uf30e' ;;
            *)           icon=$'\uf31a' ;;
        esac
    else
        icon=$'\uf11c'
    fi
    
    printf '%s' "$icon"
}
