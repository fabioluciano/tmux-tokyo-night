#!/usr/bin/env bash
# PowerKit Utility Functions
# Core utilities for PowerKit plugin system with semantic color support

# Source guard
# shellcheck disable=SC2317
if [[ -n "${_POWERKIT_UTILS_LOADED:-}" ]]; then
    return 0 2>/dev/null || true
fi
_POWERKIT_UTILS_LOADED=1

# Get current directory and source core components
CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck source=src/defaults.sh
. "$CURRENT_DIR/defaults.sh"

# =============================================================================
# PowerKit Core Functions
# =============================================================================

# Cached OS Detection
_CACHED_OS="$(uname -s)"

# OS check functions
is_macos() { [[ "$_CACHED_OS" == "Darwin" ]]; }
is_linux() { [[ "$_CACHED_OS" == Linux ]]; }

# PowerKit option getter with semantic color support
get_tmux_option() {
    local option="$1"
    local default_value="$2"
    
    tmux show-option -gqv "$option" 2>/dev/null || printf '%s' "$default_value"
}

# PowerKit plugin option getter
get_powerkit_plugin_option() {
    local plugin_name="$1"
    local option_name="$2"
    local default_value="$3"
    
    local option="@powerkit_plugin_${plugin_name}_${option_name}"
    get_tmux_option "$option" "$default_value"
}

# =============================================================================
# PowerKit Separator System with Auto-detection
# =============================================================================

# Get appropriate separator with Powerline font detection
get_powerkit_separator() {
    local separator_type="$1"  # "left", "right", "left_inverse", "right_inverse"
    local force_ascii="${2:-false}"
    
    # If ASCII is forced or we're in a limited environment, use ASCII
    if [[ "$force_ascii" == "true" ]] || [[ -n "${POWERKIT_FORCE_ASCII_SEPARATORS:-}" ]]; then
        case "$separator_type" in
            "left") echo "$POWERKIT_DEFAULT_LEFT_SEPARATOR_ASCII" ;;
            "right") echo "$POWERKIT_DEFAULT_RIGHT_SEPARATOR_ASCII" ;;
            "left_inverse") echo "$POWERKIT_DEFAULT_LEFT_SEPARATOR_INVERSE_ASCII" ;;
            "right_inverse") echo "$POWERKIT_DEFAULT_RIGHT_SEPARATOR_INVERSE_ASCII" ;;
            *) echo ">" ;;
        esac
    else
        # Use Powerline characters (may not display correctly without proper font)
        case "$separator_type" in
            "left") echo "$POWERKIT_DEFAULT_LEFT_SEPARATOR" ;;
            "right") echo "$POWERKIT_DEFAULT_RIGHT_SEPARATOR" ;;
            "left_inverse") echo "$POWERKIT_DEFAULT_LEFT_SEPARATOR_INVERSE" ;;
            "right_inverse") echo "$POWERKIT_DEFAULT_RIGHT_SEPARATOR_INVERSE" ;;
            *) echo "$POWERKIT_DEFAULT_LEFT_SEPARATOR" ;;
        esac
    fi
}

# =============================================================================
# PowerKit Semantic Color System
# =============================================================================

# Global theme colors array - populated by theme files
declare -A POWERKIT_THEME_COLORS

# Load PowerKit theme and populate colors
load_powerkit_theme() {
    local theme_family theme_variant
    
    # Check if @powerkit_theme is set (simplified format)
    local powerkit_theme=$(get_tmux_option "@powerkit_theme" "")
    
    if [[ -n "$powerkit_theme" ]]; then
        # Use theme name directly as family
        theme_family="$powerkit_theme"
        
        # Auto-detect variant from available files
        local theme_dir="$CURRENT_DIR/themes/${theme_family}"
        if [[ -d "$theme_dir" ]]; then
            # Get first available variant (alphabetically sorted)
            local first_variant
            first_variant=$(ls "$theme_dir"/*.sh 2>/dev/null | head -1 | xargs basename -s .sh 2>/dev/null || echo "")
            if [[ -n "$first_variant" ]]; then
                theme_variant="$first_variant"
            else
                # No variants found, fallback to defaults
                theme_family="$POWERKIT_DEFAULT_THEME_FAMILY"
                theme_variant="$POWERKIT_DEFAULT_THEME_VARIANT"
            fi
        else
            # Theme directory doesn't exist, fallback to defaults
            theme_family="$POWERKIT_DEFAULT_THEME_FAMILY"
            theme_variant="$POWERKIT_DEFAULT_THEME_VARIANT"
        fi
    else
        # Get theme family (e.g., "tokyo-night", "dracula", "nord")
        theme_family=$(get_tmux_option "@powerkit_theme_family" "$POWERKIT_DEFAULT_THEME_FAMILY")
        
        # Get theme variant (e.g., "night", "storm", "day", "moon")
        theme_variant=$(get_tmux_option "@powerkit_theme_variant" "$POWERKIT_DEFAULT_THEME_VARIANT")
    fi
    
    # If no variant specified, get the first available variant for this theme
    if [[ -z "$theme_variant" ]]; then
        local theme_dir="$CURRENT_DIR/themes/${theme_family}"
        if [[ -d "$theme_dir" ]]; then
            # Get first .sh file as default variant
            local first_variant
            first_variant=$(ls "$theme_dir"/*.sh 2>/dev/null | head -1 | xargs basename -s .sh 2>/dev/null || echo "")
            if [[ -n "$first_variant" ]]; then
                theme_variant="$first_variant"
            else
                # Fallback to tokyo-night night if theme family doesn't exist
                theme_family="tokyo-night"
                theme_variant="night"
            fi
        else
            # Fallback to tokyo-night night if theme family doesn't exist
            theme_family="tokyo-night"
            theme_variant="night"
        fi
    fi
    
    # Load theme file
    local theme_file="$CURRENT_DIR/themes/${theme_family}/${theme_variant}.sh"
    if [[ -f "$theme_file" ]]; then
        # shellcheck source=/dev/null
        . "$theme_file"
        
        # Copy THEME_COLORS to POWERKIT_THEME_COLORS
        if declare -p THEME_COLORS &>/dev/null; then
            local key
            for key in "${!THEME_COLORS[@]}"; do
                POWERKIT_THEME_COLORS["$key"]="${THEME_COLORS[$key]}"
            done
        fi
    fi
}

# Get semantic color with fallback
# Usage: get_powerkit_color "accent" [fallback_color]
get_powerkit_color() {
    local color_name="$1"
    local fallback="${2:-}"
    
    # Initialize theme colors if not loaded
    if [[ -z "${POWERKIT_THEME_COLORS+x}" ]] || [[ "${#POWERKIT_THEME_COLORS[@]}" -eq 0 ]]; then
        load_powerkit_theme
    fi
    
    # Return theme color if exists
    if [[ -n "${POWERKIT_THEME_COLORS[$color_name]:-}" ]]; then
        printf '%s' "${POWERKIT_THEME_COLORS[$color_name]}"
        return 0
    fi
    
    # No palette fallback - only use themes
    
    # Return fallback or original color name
    printf '%s' "${fallback:-$color_name}"
}

# Get plugin color with semantic fallback
# Usage: get_powerkit_plugin_color "battery" "accent" [fallback]
get_powerkit_plugin_color() {
    local plugin_name="$1"
    local color_type="$2"
    local fallback="${3:-}"
    
    # Try plugin-specific color first
    local plugin_color
    plugin_color=$(get_powerkit_plugin_option "$plugin_name" "${color_type}_color" "")
    
    if [[ -n "$plugin_color" ]]; then
        # Resolve semantic color if needed
        if [[ "$plugin_color" =~ ^(accent|primary|secondary|success|warning|error|info|text|background)$ ]]; then
            get_powerkit_color "$plugin_color" "$fallback"
        else
            printf '%s' "$plugin_color"
        fi
        return 0
    fi
    
    # Fall back to semantic color
    get_powerkit_color "$color_type" "$fallback"
}

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

	session_icon=$(get_tmux_option "@powerkit_session_icon" "$POWERKIT_DEFAULT_SESSION_ICON")
	
	# Auto-detect OS icon if set to "auto"
	if [[ "$session_icon" == "auto" ]]; then
		session_icon=$(get_os_icon)
	fi
	
	left_separator=$(get_tmux_option "@powerkit_left_separator" "$POWERKIT_DEFAULT_LEFT_SEPARATOR")
	transparent=$(get_tmux_option "@powerkit_transparent_status_bar" "false")

	if [ "$transparent" = "true" ]; then
		local separator_end="#[bg=default]#{?client_prefix,#[fg=$(get_powerkit_color 'warning')],#[fg=$(get_powerkit_color 'success')]}${left_separator:?}#[none]"
	else
		local separator_end="#{?client_prefix,#[fg=$(get_powerkit_color 'warning')],#[fg=$(get_powerkit_color 'success')}${left_separator:?}#[none]"
	fi

	local text=$(get_powerkit_color 'surface')
	local warning_bg=$(get_powerkit_color 'warning')
	local success_bg=$(get_powerkit_color 'success')
    
	echo "#[fg=${text},bold]#{?client_prefix,#[bg=${warning_bg}],#[bg=${success_bg}]}${session_icon} #S${separator_end}"
}

function generate_inactive_window_string() {

	inactive_window_icon=$(get_tmux_option "@powerkit_inactive_window_icon" "$POWERKIT_DEFAULT_INACTIVE_WINDOW_ICON")
	zoomed_window_icon=$(get_tmux_option "@powerkit_zoomed_window_icon" "$POWERKIT_DEFAULT_ZOOMED_WINDOW_ICON")
	local left_separator=$(get_tmux_option "@powerkit_left_separator" "$POWERKIT_DEFAULT_LEFT_SEPARATOR")
	transparent=$(get_tmux_option "@powerkit_transparent_status_bar" "false")
	inactive_window_title=$(get_tmux_option "@powerkit_inactive_window_title" "$POWERKIT_DEFAULT_INACTIVE_WINDOW_TITLE")

	# Use PowerKit colors from theme
	local number_bg=$(get_powerkit_color 'border-strong')
	local content_bg=$(get_powerkit_color 'border')
	local status_bg=$(get_powerkit_color 'surface')
	local text_color=$(get_powerkit_color 'text')

	# Get active window colors for proper separator detection
	local active_number_bg_color=$(get_tmux_option "@powerkit_active_window_number_bg" "$POWERKIT_DEFAULT_ACTIVE_WINDOW_NUMBER_BG")
	local active_content_bg_color=$(get_tmux_option "@powerkit_active_window_content_bg" "$POWERKIT_DEFAULT_ACTIVE_WINDOW_CONTENT_BG")
	local active_number_bg=$(get_powerkit_color "$active_number_bg_color" "$active_number_bg_color")
	local active_content_bg=$(get_powerkit_color "$active_content_bg_color" "$active_content_bg_color")

	# Dynamic previous window background detection
	# Always use content_bg of the window to the left
	# If first window, use session colors; otherwise check if previous window is active
	local previous_bg="#{?#{==:#{e|-:#{window_index},1},0},#{?client_prefix,$(get_powerkit_color 'warning'),$(get_powerkit_color 'success')},#{?#{==:#{e|-:#{window_index},1},#{active_window_index}},${active_content_bg},${content_bg}}}"
	
	local before_separator_internal="#[bg=${number_bg},fg=${previous_bg}]${left_separator:?}"
	local after_separator_internal="#[bg=${content_bg},fg=${number_bg}]${left_separator:?}"

	echo "${before_separator_internal}#[bg=${number_bg},fg=${text_color}] #I${after_separator_internal} #[bg=${content_bg},fg=${text_color}] #{?window_zoomed_flag,$zoomed_window_icon,$inactive_window_icon} ${inactive_window_title}"
}

function generate_active_window_string() {
	active_window_icon=$(get_tmux_option "@powerkit_active_window_icon" "$POWERKIT_DEFAULT_ACTIVE_WINDOW_ICON")
	zoomed_window_icon=$(get_tmux_option "@powerkit_zoomed_window_icon" "$POWERKIT_DEFAULT_ZOOMED_WINDOW_ICON")
	pane_synchronized_icon=$(get_tmux_option "@powerkit_pane_synchronized_icon" "$POWERKIT_DEFAULT_PANE_SYNCHRONIZED_ICON")
	left_separator=$(get_tmux_option "@powerkit_left_separator" "$POWERKIT_DEFAULT_LEFT_SEPARATOR")
	transparent=$(get_tmux_option "@powerkit_transparent_status_bar" "false")
	active_window_title=$(get_tmux_option "@powerkit_active_window_title" "$POWERKIT_DEFAULT_ACTIVE_WINDOW_TITLE")
	
	# Get customizable colors for active window
	local number_bg_color=$(get_tmux_option "@powerkit_active_window_number_bg" "$POWERKIT_DEFAULT_ACTIVE_WINDOW_NUMBER_BG")
	local content_bg_color=$(get_tmux_option "@powerkit_active_window_content_bg" "$POWERKIT_DEFAULT_ACTIVE_WINDOW_CONTENT_BG")
	
	# Resolve color names using PowerKit system
	local number_bg=$(get_powerkit_color "$number_bg_color" "$number_bg_color")
	local content_bg=$(get_powerkit_color "$content_bg_color" "$content_bg_color")

	# Get inactive window colors for proper separator detection
	local inactive_number_bg=$(get_powerkit_color 'border-strong')
	local inactive_content_bg=$(get_powerkit_color 'border')

	# Dynamic previous window background detection
	# Always use content_bg of the window to the left
	# If first window, use session colors; otherwise use inactive_content_bg (since previous window is always inactive when current is active)
	local previous_bg="#{?#{==:#{window_index},1},#{?client_prefix,$(get_powerkit_color 'warning'),$(get_powerkit_color 'success')},${inactive_content_bg}}"

	local text_color=$(get_powerkit_color 'text')
	local status_bg=$(get_powerkit_color 'surface')

	local before_separator_internal="#[bg=${number_bg},fg=${previous_bg}]${left_separator:?}#[none]"
	local after_separator_internal="#[bg=${content_bg},fg=${number_bg}]${left_separator:?}#[none]"
	
	echo "${before_separator_internal}#[bg=${number_bg},fg=${text_color}]#[bg=${number_bg},fg=${text_color},bold] #I${after_separator_internal}#[bg=${content_bg},fg=${text_color},bold] #{?window_zoomed_flag,$zoomed_window_icon,$active_window_icon} ${active_window_title}#{?pane_synchronized,$pane_synchronized_icon,}"
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
