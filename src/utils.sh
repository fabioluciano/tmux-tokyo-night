#!/usr/bin/env bash
# =============================================================================
# Utility Functions for tmux-tokyo-night
# =============================================================================

# Source guard - prevent multiple sourcing
# shellcheck disable=SC2317
if [[ -n "${_TMUX_TOKYO_NIGHT_UTILS_LOADED:-}" ]]; then
    # Already loaded, just return (don't exit as we might be in a subshell)
    return 0 2>/dev/null || true
fi
_TMUX_TOKYO_NIGHT_UTILS_LOADED=1

# =============================================================================
# Cached OS Detection
# =============================================================================
# Detect OS once and cache for all plugins to avoid repeated uname calls
_CACHED_OS="$(uname -s)"

# Convenience functions for OS checks
is_macos() { [[ "$_CACHED_OS" == "Darwin" ]]; }
is_linux() { [[ "$_CACHED_OS" == Linux ]]; }

# -----------------------------------------------------------------------------
# Get tmux option value with fallback default
# Arguments:
#   $1 - Option name
#   $2 - Default value
# Output:
#   Option value or default
# -----------------------------------------------------------------------------
get_tmux_option() {
    local option="$1"
    local default_value="$2"
    local option_value
    
    option_value=$(tmux show-option -gqv "$option")
    
    if [[ -z "$option_value" ]]; then
        printf '%s' "$default_value"
    else
        printf '%s' "$option_value"
    fi
}

function generate_left_side_string() {

	session_icon=$(get_tmux_option "@theme_session_icon" " ")
	left_separator=$(get_tmux_option "@theme_left_separator" "")
	transparent=$(get_tmux_option "@theme_transparent_status_bar" "false")

	if [ "$transparent" = "true" ]; then
		local separator_end="#[bg=default]#{?client_prefix,#[fg=${PALLETE[yellow]}],#[fg=${PALLETE[green]}]}${left_separator:?}#[none]"
	else
		local separator_end="#[bg=${PALLETE[bg_highlight]}]#{?client_prefix,#[fg=${PALLETE[yellow]}],#[fg=${PALLETE[green]}]}${left_separator:?}#[none]"
	fi

	echo "#[fg=${PALLETE[fg_gutter]},bold]#{?client_prefix,#[bg=${PALLETE[yellow]}],#[bg=${PALLETE[green]}]} ${session_icon} #S ${separator_end}"
}

function generate_inactive_window_string() {

	inactive_window_icon=$(get_tmux_option "@theme_plugin_inactive_window_icon" " ")
	zoomed_window_icon=$(get_tmux_option "@theme_plugin_zoomed_window_icon" " ")
	left_separator=$(get_tmux_option "@theme_left_separator" "")
	transparent=$(get_tmux_option "@theme_transparent_status_bar" "false")
	inactive_window_title=$(get_tmux_option "@theme_inactive_window_title" "#W ")

	if [ "$transparent" = "true" ]; then
		left_separator_inverse=$(get_tmux_option "@theme_transparent_left_separator_inverse" "")

		local separator_start="#[bg=default,fg=${PALLETE['dark5']}]${left_separator_inverse}#[bg=${PALLETE['dark5']},fg=${PALLETE['bg_highlight']}]"
		local separator_internal="#[bg=${PALLETE['dark3']},fg=${PALLETE['dark5']}]${left_separator:?}#[none]"
		local separator_end="#[bg=default,fg=${PALLETE['dark3']}]${left_separator:?}#[none]"
	else
		local separator_start="#[bg=${PALLETE['dark5']},fg=${PALLETE['bg_highlight']}]${left_separator:?}#[none]"
		local separator_internal="#[bg=${PALLETE['dark3']},fg=${PALLETE['dark5']}]${left_separator:?}#[none]"
		local separator_end="#[bg=${PALLETE[bg_highlight]},fg=${PALLETE['dark3']}]${left_separator:?}#[none]"
	fi

	echo "${separator_start}#[fg=${PALLETE[white]}]#I${separator_internal}#[fg=${PALLETE[white]}] #{?window_zoomed_flag,$zoomed_window_icon,$inactive_window_icon}${inactive_window_title}${separator_end}"
}

function generate_active_window_string() {
	active_window_icon=$(get_tmux_option "@theme_plugin_active_window_icon" " ")
	zoomed_window_icon=$(get_tmux_option "@theme_plugin_zoomed_window_icon" " ")
	pane_synchronized_icon=$(get_tmux_option "@theme_plugin_pane_synchronized_icon" "✵")
	left_separator=$(get_tmux_option "@theme_left_separator" "")
	transparent=$(get_tmux_option "@theme_transparent_status_bar" "false")
	active_window_title=$(get_tmux_option "@theme_active_window_title" "#W ")

	if [ "$transparent" = "true" ]; then
		left_separator_inverse=$(get_tmux_option "@theme_transparent_left_separator_inverse" "")
		
		separator_start="#[bg=default,fg=${PALLETE['magenta']}]${left_separator_inverse}#[bg=${PALLETE['magenta']},fg=${PALLETE['bg_highlight']}]"
		separator_internal="#[bg=${PALLETE['purple']},fg=${PALLETE['magenta']}]${left_separator:?}#[none]"
		separator_end="#[bg=default,fg=${PALLETE['purple']}]${left_separator:?}#[none]"
	else
		separator_start="#[bg=${PALLETE['magenta']},fg=${PALLETE['bg_highlight']}]${left_separator:?}#[none]"
		separator_internal="#[bg=${PALLETE['purple']},fg=${PALLETE['magenta']}]${left_separator:?}#[none]"
		separator_end="#[bg=${PALLETE[bg_highlight]},fg=${PALLETE['purple']}]${left_separator:?}#[none]"
	fi

	echo "${separator_start}#[fg=${PALLETE[white]}]#I${separator_internal}#[fg=${PALLETE[white]}] #{?window_zoomed_flag,$zoomed_window_icon,$active_window_icon}${active_window_title}#{?pane_synchronized,$pane_synchronized_icon,}${separator_end}#[none]"
}

# =============================================================================
# Threshold-based Color System
# =============================================================================
# These functions provide dynamic color selection based on numeric values
# Can be used by any plugin that needs color changes based on thresholds
#
# The color selection works in two modes:
#   - "ascending": low values = low_color, high values = high_color
#     Example: CPU usage (low is good/green, high is bad/red)
#   - "descending": low values = high_color, high values = low_color
#     Example: Battery (low is bad/red, high is good/green)
# =============================================================================

# -----------------------------------------------------------------------------
# Get color based on value and thresholds (ascending mode)
# Low value = low_color (good), High value = high_color (bad)
# Arguments:
#   $1 - Current numeric value
#   $2 - Low threshold (below this = low_color)
#   $3 - High threshold (above this = high_color, between = medium_color)
#   $4 - Low color (for values below low threshold)
#   $5 - Medium color (for values between thresholds)
#   $6 - High color (for values above high threshold)
# Output:
#   Selected color name
# -----------------------------------------------------------------------------
get_threshold_color_ascending() {
    local value="$1"
    local low_threshold="$2"
    local high_threshold="$3"
    local low_color="$4"
    local medium_color="$5"
    local high_color="$6"
    
    # Remove any non-numeric characters (like %)
    value="${value//[!0-9]/}"
    
    if [[ -z "$value" ]] || [[ ! "$value" =~ ^[0-9]+$ ]]; then
        printf '%s' "$medium_color"
        return
    fi
    
    if (( value <= low_threshold )); then
        printf '%s' "$low_color"
    elif (( value >= high_threshold )); then
        printf '%s' "$high_color"
    else
        printf '%s' "$medium_color"
    fi
}

# -----------------------------------------------------------------------------
# Get color based on value and thresholds (descending mode)
# Low value = critical_color (bad), High value = normal_color (good)
# Arguments:
#   $1 - Current numeric value
#   $2 - Critical threshold (below this = critical_color)
#   $3 - Warning threshold (below this = warning_color, above = normal_color)
#   $4 - Critical color (for values below critical threshold)
#   $5 - Warning color (for values between thresholds)
#   $6 - Normal color (for values above warning threshold)
# Output:
#   Selected color name
# -----------------------------------------------------------------------------
get_threshold_color_descending() {
    local value="$1"
    local critical_threshold="$2"
    local warning_threshold="$3"
    local critical_color="$4"
    local warning_color="$5"
    local normal_color="$6"
    
    # Remove any non-numeric characters (like %)
    value="${value//[!0-9]/}"
    
    if [[ -z "$value" ]] || [[ ! "$value" =~ ^[0-9]+$ ]]; then
        printf '%s' "$normal_color"
        return
    fi
    
    if (( value <= critical_threshold )); then
        printf '%s' "$critical_color"
    elif (( value <= warning_threshold )); then
        printf '%s' "$warning_color"
    else
        printf '%s' "$normal_color"
    fi
}

# -----------------------------------------------------------------------------
# Check if value meets display threshold condition
# Arguments:
#   $1 - Current numeric value
#   $2 - Threshold value
#   $3 - Condition: "le" (<=), "lt" (<), "ge" (>=), "gt" (>), "eq" (==), "always"
# Returns:
#   0 if condition met, 1 otherwise
# -----------------------------------------------------------------------------
check_display_threshold() {
    local value="$1"
    local threshold="$2"
    local condition="${3:-always}"
    
    # "always" means always display
    [[ "$condition" == "always" ]] && return 0
    
    # Remove any non-numeric characters
    value="${value//[!0-9]/}"
    
    if [[ -z "$value" ]] || [[ ! "$value" =~ ^[0-9]+$ ]]; then
        return 1
    fi
    
    case "$condition" in
        le) (( value <= threshold )) ;;
        lt) (( value < threshold )) ;;
        ge) (( value >= threshold )) ;;
        gt) (( value > threshold )) ;;
        eq) (( value == threshold )) ;;
        *)  return 0 ;;
    esac
}
