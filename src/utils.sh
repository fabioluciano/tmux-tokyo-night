#!/usr/bin/env bash
# Utility Functions for tmux-tokyo-night

# Source guard
# shellcheck disable=SC2317
if [[ -n "${_TMUX_TOKYO_NIGHT_UTILS_LOADED:-}" ]]; then
    return 0 2>/dev/null || true
fi
_TMUX_TOKYO_NIGHT_UTILS_LOADED=1

# Cached OS Detection
_CACHED_OS="$(uname -s)"

# OS check functions
is_macos() { [[ "$_CACHED_OS" == "Darwin" ]]; }
is_linux() { [[ "$_CACHED_OS" == Linux ]]; }

# Get OS/Distribution icon
get_os_icon() {
    local cache_key="os_icon"
    local cache_ttl=86400  # 24 hours
    
    # Check cache first
    local cached_value
    if cached_value=$(cache_get "$cache_key" "$cache_ttl" 2>/dev/null); then
        printf '%s' "$cached_value"
        return 0
    fi
    
    local icon
    
    if is_macos; then
        icon=$'\uf302'
    elif is_linux; then
        # Get distro ID from os-release, then map to icon in bash
        # Note: awk doesn't support \u unicode escapes, so we parse the ID
        # and use bash's $'...' syntax for proper unicode handling
        local distro_id
        distro_id=$(awk -F'=' '/^ID=/ {gsub(/"/, "", $2); print $2; exit}' /etc/os-release 2>/dev/null)
        
        case "$distro_id" in
            ubuntu)     icon=$'\uf31b' ;;
            debian)     icon=$'\uf306' ;;
            fedora)     icon=$'\uf30a' ;;
            arch)       icon=$'\uf303' ;;
            manjaro)    icon=$'\uf312' ;;
            centos|rhel) icon=$'\uf304' ;;
            opensuse*)  icon=$'\uf314' ;;
            alpine)     icon=$'\uf300' ;;
            gentoo)     icon=$'\uf30d' ;;
            linuxmint)  icon=$'\uf30e' ;;
            *)          icon=$'\uf31a' ;;  # Generic Linux icon
        esac
    else
        icon=$'\uf11c'
    fi
    
    # Cache the result
    cache_set "$cache_key" "$icon" 2>/dev/null || true
    
    printf '%s' "$icon"
}

# -----------------------------------------------------------------------------
# Get tmux option value with fallback default
# Uses caching to avoid repeated tmux calls within the same script execution
# Arguments:
#   $1 - Option name
#   $2 - Default value
# Output:
#   Option value or default
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

	session_icon=$(get_tmux_option "@theme_session_icon" "$THEME_DEFAULT_SESSION_ICON")
	
	# Auto-detect OS icon if set to "auto"
	if [[ "$session_icon" == "auto" ]]; then
		session_icon=$(get_os_icon)
	fi
	
	left_separator=$(get_tmux_option "@theme_left_separator" "$THEME_DEFAULT_LEFT_SEPARATOR")
	transparent=$(get_tmux_option "@theme_transparent_status_bar" "false")

	if [ "$transparent" = "true" ]; then
		local separator_end="#[bg=default]#{?client_prefix,#[fg=${PALLETE[yellow]}],#[fg=${PALLETE[green]}]}${left_separator:?}#[none]"
	else
		local separator_end="#[bg=${PALLETE[bg_highlight]}]#{?client_prefix,#[fg=${PALLETE[yellow]}],#[fg=${PALLETE[green]}]}${left_separator:?}#[none]"
	fi

	echo "#[fg=${PALLETE[fg_gutter]},bold]#{?client_prefix,#[bg=${PALLETE[yellow]}],#[bg=${PALLETE[green]}]} ${session_icon} #S ${separator_end}"
}

function generate_inactive_window_string() {

	inactive_window_icon=$(get_tmux_option "@theme_plugin_inactive_window_icon" "$THEME_DEFAULT_INACTIVE_WINDOW_ICON")
	zoomed_window_icon=$(get_tmux_option "@theme_plugin_zoomed_window_icon" "$THEME_DEFAULT_ZOOMED_WINDOW_ICON")
	left_separator=$(get_tmux_option "@theme_left_separator" "$THEME_DEFAULT_LEFT_SEPARATOR")
	transparent=$(get_tmux_option "@theme_transparent_status_bar" "false")
	inactive_window_title=$(get_tmux_option "@theme_inactive_window_title" "$THEME_DEFAULT_INACTIVE_WINDOW_TITLE")

	if [ "$transparent" = "true" ]; then
		left_separator_inverse=$(get_tmux_option "@theme_left_separator_inverse" "$THEME_DEFAULT_LEFT_SEPARATOR_INVERSE")

		local separator_start="#[bg=default,fg=${PALLETE['dark5']}]${left_separator_inverse}#[bg=${PALLETE['dark5']},fg=${PALLETE['bg_highlight']}]"
		local separator_internal="#[bg=${PALLETE['dark3']},fg=${PALLETE['dark5']}]${left_separator:?}#[none]"
		local separator_end="#[bg=default,fg=${PALLETE['dark3']}]${left_separator:?}#[none]"
	else
		local separator_start="#[bg=${PALLETE['dark5']},fg=${PALLETE['bg_highlight']}]${left_separator:?}#[none]"
		local separator_internal="#[bg=${PALLETE['dark3']},fg=${PALLETE['dark5']}]${left_separator:?}#[none]"
		local separator_end="#[bg=${PALLETE[bg_highlight]},fg=${PALLETE['dark3']}]${left_separator:?}#[none]"
	fi

	echo "${separator_start}#[fg=${PALLETE[white]}]#I${separator_internal}#[fg=${PALLETE[white]}] #{?window_zoomed_flag,$zoomed_window_icon,$inactive_window_icon} ${inactive_window_title}${separator_end}"
}

function generate_active_window_string() {
	active_window_icon=$(get_tmux_option "@theme_plugin_active_window_icon" "$THEME_DEFAULT_ACTIVE_WINDOW_ICON")
	zoomed_window_icon=$(get_tmux_option "@theme_plugin_zoomed_window_icon" "$THEME_DEFAULT_ZOOMED_WINDOW_ICON")
	pane_synchronized_icon=$(get_tmux_option "@theme_plugin_pane_synchronized_icon" "$THEME_DEFAULT_PANE_SYNCHRONIZED_ICON")
	left_separator=$(get_tmux_option "@theme_left_separator" "$THEME_DEFAULT_LEFT_SEPARATOR")
	transparent=$(get_tmux_option "@theme_transparent_status_bar" "false")
	active_window_title=$(get_tmux_option "@theme_active_window_title" "$THEME_DEFAULT_ACTIVE_WINDOW_TITLE")
	
	# Get customizable colors for active window
	local number_bg_color
	local content_bg_color
	number_bg_color=$(get_tmux_option "@theme_active_window_number_bg" "$THEME_DEFAULT_ACTIVE_WINDOW_NUMBER_BG")
	content_bg_color=$(get_tmux_option "@theme_active_window_content_bg" "$THEME_DEFAULT_ACTIVE_WINDOW_CONTENT_BG")
	
	# Resolve color names from palette
	local number_bg="${PALLETE[$number_bg_color]:-$number_bg_color}"
	local content_bg="${PALLETE[$content_bg_color]:-$content_bg_color}"

	if [ "$transparent" = "true" ]; then
		left_separator_inverse=$(get_tmux_option "@theme_left_separator_inverse" "$THEME_DEFAULT_LEFT_SEPARATOR_INVERSE")
		
		separator_start="#[bg=default,fg=${number_bg}]${left_separator_inverse}#[bg=${number_bg},fg=${PALLETE['bg_highlight']}]"
		separator_internal="#[bg=${content_bg},fg=${number_bg}]${left_separator:?}#[none]"
		separator_end="#[bg=default,fg=${content_bg}]${left_separator:?}#[none]"
	else
		separator_start="#[bg=${number_bg},fg=${PALLETE['bg_highlight']}]${left_separator:?}#[none]"
		separator_internal="#[bg=${content_bg},fg=${number_bg}]${left_separator:?}#[none]"
		separator_end="#[bg=${PALLETE[bg_highlight]},fg=${content_bg}]${left_separator:?}#[none]"
	fi

	echo "${separator_start}#[fg=${PALLETE[white]}]#I${separator_internal}#[fg=${PALLETE[white]}] #{?window_zoomed_flag,$zoomed_window_icon,$active_window_icon} ${active_window_title}#{?pane_synchronized,$pane_synchronized_icon,}${separator_end}#[none]"
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
