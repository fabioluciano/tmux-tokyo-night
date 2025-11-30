#!/usr/bin/env bash
# =============================================================================
# Separator Builder Functions
# Centralizes all separator/segment construction logic for the theme
# =============================================================================

# Source guard - prevent multiple sourcing
# shellcheck disable=SC2317
if [[ -n "${_TMUX_TOKYO_NIGHT_SEPARATORS_LOADED:-}" ]]; then
    return 0 2>/dev/null || true
fi
_TMUX_TOKYO_NIGHT_SEPARATORS_LOADED=1

# =============================================================================
# Separator Construction Functions
# =============================================================================
# These functions build the tmux format strings for powerline-style separators
# Used by theme.sh, conditional_plugin.sh, and threshold_plugin.sh
# =============================================================================

# -----------------------------------------------------------------------------
# Build the icon start separator (transition from bg_highlight to icon color)
# Arguments:
#   $1 - accent_color_icon - Icon background color
#   $2 - bg_highlight - Background highlight color
#   $3 - right_separator - Separator character (e.g., )
#   $4 - transparent - "true" or "false"
# Output:
#   Formatted separator string
# -----------------------------------------------------------------------------
build_separator_icon_start() {
    local accent_color_icon="$1"
    local bg_highlight="$2"
    local right_separator="$3"
    local transparent="${4:-false}"
    
    if [[ "$transparent" == "true" ]]; then
        printf '%s' "#[fg=${accent_color_icon},bg=default]${right_separator}#[none]"
    else
        printf '%s' "#[fg=${accent_color_icon},bg=${bg_highlight}]${right_separator}#[none]"
    fi
}

# -----------------------------------------------------------------------------
# Build the icon end separator (transition from icon to content)
# Arguments:
#   $1 - accent_color - Content background color
#   $2 - accent_color_icon - Icon background color
#   $3 - right_separator - Separator character
# Output:
#   Formatted separator string
# -----------------------------------------------------------------------------
build_separator_icon_end() {
    local accent_color="$1"
    local accent_color_icon="$2"
    local right_separator="$3"
    
    printf '%s' "#[fg=${accent_color},bg=${accent_color_icon}]${right_separator}#[none]"
}

# -----------------------------------------------------------------------------
# Build the segment end separator (transition from content to bg_highlight)
# Arguments:
#   $1 - accent_color - Content background color
#   $2 - bg_highlight - Background highlight color
#   $3 - right_separator - Separator character
#   $4 - transparent - "true" or "false"
#   $5 - right_separator_inverse - Inverse separator for transparent mode
# Output:
#   Formatted separator string
# -----------------------------------------------------------------------------
build_separator_end() {
    local accent_color="$1"
    local bg_highlight="$2"
    local right_separator="$3"
    local transparent="${4:-false}"
    local right_separator_inverse="${5:-}"
    
    if [[ "$transparent" == "true" ]]; then
        printf '%s' "#[fg=${accent_color},bg=default]${right_separator_inverse}#[bg=default]"
    else
        printf '%s' "#[fg=${bg_highlight},bg=${accent_color}]${right_separator}#[bg=${bg_highlight}]"
    fi
}

# -----------------------------------------------------------------------------
# Build entry separator for conditional plugins
# (transition from previous plugin's accent to bg_highlight)
# Arguments:
#   $1 - prev_accent_color - Previous plugin's accent color
#   $2 - bg_highlight - Background highlight color
#   $3 - right_separator - Separator character
#   $4 - transparent - "true" or "false"
#   $5 - right_separator_inverse - Inverse separator for transparent mode
# Output:
#   Formatted separator string
# -----------------------------------------------------------------------------
build_entry_separator() {
    local prev_accent_color="$1"
    local bg_highlight="$2"
    local right_separator="$3"
    local transparent="${4:-false}"
    local right_separator_inverse="${5:-}"
    
    if [[ "$transparent" == "true" ]]; then
        printf '%s' "#[fg=${prev_accent_color},bg=default]${right_separator_inverse}#[bg=default]"
    else
        printf '%s' "#[fg=${prev_accent_color},bg=${bg_highlight}]${right_separator}#[bg=${bg_highlight}]"
    fi
}

# -----------------------------------------------------------------------------
# Build complete plugin icon section
# Arguments:
#   $1 - separator_icon_start - Pre-built or will be constructed
#   $2 - separator_icon_end - Pre-built or will be constructed
#   $3 - white_color - Foreground color for icon
#   $4 - accent_color_icon - Background color for icon
#   $5 - plugin_icon - Icon character (without trailing space)
# Output:
#   Formatted icon section string
# -----------------------------------------------------------------------------
build_icon_section() {
    local sep_icon_start="$1"
    local sep_icon_end="$2"
    local white_color="$3"
    local accent_color_icon="$4"
    local plugin_icon="$5"
    
    printf '%s' "${sep_icon_start}#[fg=${white_color},bg=${accent_color_icon}]${plugin_icon} ${sep_icon_end}"
}

# -----------------------------------------------------------------------------
# Build plugin content section
# Arguments:
#   $1 - white_color - Foreground color
#   $2 - accent_color - Background color
#   $3 - content - Plugin content text
#   $4 - is_last - "1" if last plugin (no trailing space), "0" otherwise
# Output:
#   Formatted content section string
# -----------------------------------------------------------------------------
build_content_section() {
    local white_color="$1"
    local accent_color="$2"
    local content="$3"
    local is_last="${4:-0}"
    
    if [[ "$is_last" == "1" ]]; then
        printf '%s' "#[fg=${white_color},bg=${accent_color}]${content}#[none]"
    else
        printf '%s' "#[fg=${white_color},bg=${accent_color}]${content} #[none]"
    fi
}

# -----------------------------------------------------------------------------
# Build complete plugin segment
# Arguments:
#   $1 - icon_output - Pre-built icon section
#   $2 - content_output - Pre-built content section
#   $3 - separator_end - End separator (or empty for last plugin)
#   $4 - is_last - "1" if last plugin, "0" otherwise
# Output:
#   Complete formatted plugin segment
# -----------------------------------------------------------------------------
build_plugin_segment() {
    local icon_output="$1"
    local content_output="$2"
    local separator_end="$3"
    local is_last="${4:-0}"
    
    if [[ "$is_last" != "1" ]]; then
        printf '%s' "${icon_output}${content_output}${separator_end}"
    else
        printf '%s' "${icon_output}${content_output}"
    fi
}
