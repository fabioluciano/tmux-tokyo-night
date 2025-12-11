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
# Platform Detection (cached, computed once)
# =============================================================================

declare -g _PLATFORM_OS=""
declare -g _PLATFORM_DISTRO=""
declare -g _PLATFORM_ARCH=""
declare -g _PLATFORM_ICON=""

_detect_platform() {
    [[ -n "$_PLATFORM_OS" ]] && return 0
    
    _PLATFORM_OS="$(uname -s)"
    _PLATFORM_ARCH="$(uname -m)"
    
    case "$_PLATFORM_OS" in
        Darwin)
            _PLATFORM_DISTRO="macos"
            _PLATFORM_ICON=$'\uf302'
            ;;
        Linux)
            # Detect distro from /etc/os-release
            if [[ -f /etc/os-release ]]; then
                _PLATFORM_DISTRO=$(awk -F'=' '/^ID=/ {gsub(/"/, "", $2); print tolower($2); exit}' /etc/os-release)
            elif [[ -f /etc/lsb-release ]]; then
                _PLATFORM_DISTRO=$(awk -F'=' '/^DISTRIB_ID=/ {print tolower($2); exit}' /etc/lsb-release)
            else
                _PLATFORM_DISTRO="linux"
            fi
            # Set icon based on distro
            case "$_PLATFORM_DISTRO" in
                ubuntu)         _PLATFORM_ICON=$'\uf31b' ;;
                debian)         _PLATFORM_ICON=$'\uf306' ;;
                fedora)         _PLATFORM_ICON=$'\uf30a' ;;
                arch|archarm)   _PLATFORM_ICON=$'\uf303' ;;
                manjaro)        _PLATFORM_ICON=$'\uf312' ;;
                centos)         _PLATFORM_ICON=$'\uf304' ;;
                rhel|redhat)    _PLATFORM_ICON=$'\uf304' ;;
                opensuse*)      _PLATFORM_ICON=$'\uf314' ;;
                alpine)         _PLATFORM_ICON=$'\uf300' ;;
                gentoo)         _PLATFORM_ICON=$'\uf30d' ;;
                linuxmint|mint) _PLATFORM_ICON=$'\uf30e' ;;
                elementary)     _PLATFORM_ICON=$'\uf309' ;;
                pop|pop_os)     _PLATFORM_ICON=$'\uf32a' ;;
                kali)           _PLATFORM_ICON=$'\uf327' ;;
                void)           _PLATFORM_ICON=$'\uf32e' ;;
                nixos|nix)      _PLATFORM_ICON=$'\uf313' ;;
                raspbian)       _PLATFORM_ICON=$'\uf315' ;;
                rocky)          _PLATFORM_ICON=$'\uf32b' ;;
                alma|almalinux) _PLATFORM_ICON=$'\uf31d' ;;
                endeavouros)    _PLATFORM_ICON=$'\uf322' ;;
                garuda)         _PLATFORM_ICON=$'\uf337' ;;
                artix)          _PLATFORM_ICON=$'\uf31f' ;;
                *)              _PLATFORM_ICON=$'\uf31a' ;;
            esac
            ;;
        FreeBSD)  _PLATFORM_DISTRO="freebsd"; _PLATFORM_ICON=$'\uf30c' ;;
        OpenBSD)  _PLATFORM_DISTRO="openbsd"; _PLATFORM_ICON=$'\uf328' ;;
        NetBSD)   _PLATFORM_DISTRO="netbsd";  _PLATFORM_ICON=$'\uf328' ;;
        CYGWIN*|MINGW*|MSYS*) _PLATFORM_OS="Windows"; _PLATFORM_DISTRO="windows"; _PLATFORM_ICON=$'\uf17a' ;;
        *)        _PLATFORM_DISTRO="unknown"; _PLATFORM_ICON=$'\uf11c' ;;
    esac
}

# Initialize on load
_detect_platform

# --- OS Detection ---
is_macos()  { [[ "$_PLATFORM_OS" == "Darwin" ]]; }
is_linux()  { [[ "$_PLATFORM_OS" == "Linux" ]]; }
is_bsd()    { [[ "$_PLATFORM_OS" == *"BSD" ]]; }
is_windows(){ [[ "$_PLATFORM_OS" == "Windows" ]] || [[ -n "${WSL_DISTRO_NAME:-}" ]]; }

# --- Distro Detection ---
is_distro()       { [[ "$_PLATFORM_DISTRO" == "$1" ]]; }
is_debian_based() { [[ "$_PLATFORM_DISTRO" =~ ^(debian|ubuntu|mint|pop|elementary|kali|raspbian)$ ]] || command -v apt &>/dev/null; }
is_redhat_based() { [[ "$_PLATFORM_DISTRO" =~ ^(rhel|fedora|centos|rocky|alma)$ ]] || command -v dnf &>/dev/null; }
is_arch_based()   { [[ "$_PLATFORM_DISTRO" =~ ^(arch|manjaro|endeavouros|garuda|artix)$ ]] || command -v pacman &>/dev/null; }

# --- Architecture Detection ---
is_arm()          { [[ "$_PLATFORM_ARCH" == arm* || "$_PLATFORM_ARCH" == "aarch64" ]]; }
is_apple_silicon(){ is_macos && is_arm; }

# --- Getters ---
get_os()     { printf '%s' "$_PLATFORM_OS"; }
get_distro() { printf '%s' "$_PLATFORM_DISTRO"; }
get_arch()   { printf '%s' "$_PLATFORM_ARCH"; }
get_os_icon(){ printf ' %s' "$_PLATFORM_ICON"; }

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
    local theme="" theme_variant="" theme_dir="" theme_file=""
    
    # Get theme name
    theme=$(get_tmux_option "@powerkit_theme" "$POWERKIT_DEFAULT_THEME")
    theme_variant=$(get_tmux_option "@powerkit_theme_variant" "")
    
    # Auto-detect variant if not specified
    if [[ -z "$theme_variant" ]]; then
        theme_dir="$CURRENT_DIR/themes/${theme}"
        if [[ -d "$theme_dir" ]]; then
            theme_variant=$(ls "$theme_dir"/*.sh 2>/dev/null | head -1 | xargs basename -s .sh 2>/dev/null || echo "")
        fi
    fi
    
    # Fallback to defaults
    [[ -z "$theme_variant" ]] && theme_variant="$POWERKIT_DEFAULT_THEME_VARIANT"
    
    # Final fallback
    [[ -z "$theme" ]] && theme="tokyo-night"
    [[ -z "$theme_variant" ]] && theme_variant="night"
    
    # Load theme file
    theme_file="$CURRENT_DIR/themes/${theme}/${theme_variant}.sh"
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
    
    # Load theme if not loaded (handle unset array safely)
    if [[ -z "${POWERKIT_THEME_COLORS[*]+x}" ]] || [[ ${#POWERKIT_THEME_COLORS[@]} -eq 0 ]]; then
        load_powerkit_theme
    fi
    
    # Return theme color or fallback
    printf '%s' "${POWERKIT_THEME_COLORS[$color_name]:-$fallback}"
}

# Alias for get_powerkit_color (shorter name for use in render scripts)
get_color() { get_powerkit_color "$@"; }

# =============================================================================
# Generic Utility Functions
# =============================================================================

# Extract first numeric value from a string
# Usage: extract_numeric "CPU: 45%" -> "45"
extract_numeric() {
    local content="$1"
    echo "$content" | grep -oE '[0-9]+' | head -1
}

# Evaluate a numeric condition
# Usage: evaluate_condition <value> <condition> <threshold>
# Conditions: lt, le, gt, ge, eq, ne, always
# Returns: 0 if condition met, 1 otherwise
evaluate_condition() {
    local value="$1"
    local condition="$2"
    local threshold="$3"
    
    [[ "$condition" == "always" || "$condition" == "$POWERKIT_CONDITION_ALWAYS" ]] && return 0
    [[ -z "$threshold" || -z "$value" ]] && return 0
    
    case "$condition" in
        lt) (( value < threshold )) ;;
        le) (( value <= threshold )) ;;
        gt) (( value > threshold )) ;;
        ge) (( value >= threshold )) ;;
        eq) (( value == threshold )) ;;
        ne) (( value != threshold )) ;;
        *)  return 0 ;;
    esac
}

# Build display info string for plugins
# Usage: build_display_info <show> [accent] [accent_icon] [icon]
build_display_info() {
    local show="${1:-1}"
    local accent="${2:-}"
    local accent_icon="${3:-}"
    local icon="${4:-}"
    
    printf '%s:%s:%s:%s' "$show" "$accent" "$accent_icon" "$icon"
}

# =============================================================================
# Toast Notification (Popup UI)
# Generic toast notification that stays visible until user dismisses
# =============================================================================

# Show a toast notification with custom content from a file
# Usage: show_toast_notification <title> <content_file> [width] [height]
# Example: show_toast_notification "⚠️  Warning" "/path/to/content.log" 70 20
show_toast_notification() {
    local title="$1"
    local content_file="$2"
    local popup_width="${3:-70}"
    local popup_height="${4:-20}"
    
    [[ ! -f "$content_file" ]] && {
        tmux display-message -d 3000 "Toast error: content file not found" 2>/dev/null || true
        return 1
    }
    
    # Check if tmux supports display-popup (tmux >= 3.2)
    local tmux_version
    tmux_version=$(tmux -V 2>/dev/null | grep -oE '[0-9]+\.[0-9]+' | head -1)
    local major minor
    major="${tmux_version%%.*}"
    minor="${tmux_version##*.}"
    
    # If tmux >= 3.2, use display-popup for better UX
    if [[ "$major" -gt 3 ]] || { [[ "$major" -eq 3 ]] && [[ "$minor" -ge 2 ]]; }; then
        # Create a temporary script for the popup content
        local popup_script="${CACHE_DIR}/toast_notification.sh"
        
        cat > "$popup_script" << 'TOAST_EOF'
#!/usr/bin/env bash
# PowerKit Toast Notification

# Colors
RED='\033[0;31m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
DIM='\033[2m'
NC='\033[0m'

clear
echo ""

# Display content from file
content_file="$1"
if [[ -f "$content_file" ]]; then
    cat "$content_file"
fi

echo ""
echo -e "  ${DIM}─────────────────────────────────────────────────────────────${NC}"
echo -e "  ${WHITE}Press any key to dismiss...${NC}"
echo ""

read -rsn1
TOAST_EOF

        chmod +x "$popup_script"
        
        # Show popup (runs async, user dismisses with any key)
        tmux display-popup -E -w "$popup_width" -h "$popup_height" \
            -T " $title " \
            "bash '$popup_script' '$content_file'" 2>/dev/null || {
            # Fallback to display-message if popup fails
            local first_line
            first_line=$(head -n1 "$content_file" 2>/dev/null)
            tmux display-message -d 10000 "$title - $first_line" 2>/dev/null || true
        }
    else
        # Fallback for older tmux versions - longer display time
        local first_line
        first_line=$(head -n1 "$content_file" 2>/dev/null)
        tmux display-message -d 10000 "$title - $first_line" 2>/dev/null || true
    fi
}
