#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# Unified Plugin Renderer (KISS/DRY)
# Usage: render_plugins.sh "name:accent:accent_icon:icon:type;..."
# Types: static, conditional
# =============================================================================

CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Bootstrap (loads defaults, utils, cache, plugin_helpers)
# shellcheck source=src/plugin_bootstrap.sh
. "${CURRENT_DIR}/plugin_bootstrap.sh"

# Load theme
THEME_FAMILY=$(get_tmux_option "@powerkit_theme_family" "$POWERKIT_DEFAULT_THEME_FAMILY")
THEME_VARIANT=$(get_tmux_option "@powerkit_theme_variant" "$POWERKIT_DEFAULT_THEME_VARIANT")
THEME_FILE="${CURRENT_DIR}/themes/${THEME_FAMILY}/${THEME_VARIANT}.sh"
[[ -f "$THEME_FILE" ]] && . "$THEME_FILE"

# =============================================================================
# Configuration
# =============================================================================
TEXT_COLOR="${RENDER_TEXT_COLOR:-#ffffff}"
STATUS_BG="${RENDER_STATUS_BG:-${POWERKIT_FALLBACK_STATUS_BG:-#1a1b26}}"
TRANSPARENT="${RENDER_TRANSPARENT:-false}"
PLUGINS_CONFIG="${1:-}"

RIGHT_SEPARATOR=$(get_tmux_option "@powerkit_right_separator" "$POWERKIT_DEFAULT_RIGHT_SEPARATOR")
RIGHT_SEPARATOR_INVERSE=$(get_tmux_option "@powerkit_right_separator_inverse" "$POWERKIT_DEFAULT_RIGHT_SEPARATOR_INVERSE")

# =============================================================================
# Helpers
# =============================================================================

# Resolve color name to hex (from theme or pass-through)
get_color() {
    local name="$1"
    [[ -z "$name" ]] && return
    printf '%s' "${THEME_COLORS[$name]:-$name}"
}

# Get plugin defaults from defaults.sh
get_plugin_defaults() {
    local name="$1"
    local upper="${name^^}"
    upper="${upper//-/_}"
    
    local accent_var="POWERKIT_PLUGIN_${upper}_ACCENT_COLOR"
    local accent_icon_var="POWERKIT_PLUGIN_${upper}_ACCENT_COLOR_ICON"
    local icon_var="POWERKIT_PLUGIN_red${upper}_ICON"
    
    printf '%s:%s:%s' "${!accent_var:-secondary}" "${!accent_icon_var:-active}" "${!icon_var:-}"
}

# Apply threshold colors if defined
apply_thresholds() {
    local name="$1" content="$2" accent="$3" accent_icon="$4"
    local upper="${name^^}"
    upper="${upper//-/_}"
    
    local num
    num=$(echo "$content" | grep -oE '[0-9]+' | head -1)
    [[ -z "$num" ]] && { printf '%s:%s' "$accent" "$accent_icon"; return; }
    
    local warn_var="POWERKIT_PLUGIN_${upper}_WARNING_THRESHOLD"
    local crit_var="POWERKIT_PLUGIN_${upper}_CRITICAL_THRESHOLD"
    local warn="${!warn_var:-}" crit="${!crit_var:-}"
    
    [[ -z "$warn" || -z "$crit" ]] && { printf '%s:%s' "$accent" "$accent_icon"; return; }
    
    if [[ "$num" -ge "$crit" ]]; then
        local ca="POWERKIT_PLUGIN_${upper}_CRITICAL_ACCENT_COLOR"
        local ci="POWERKIT_PLUGIN_${upper}_CRITICAL_ACCENT_COLOR_ICON"
        printf '%s:%s' "${!ca:-$accent}" "${!ci:-$accent_icon}"
    elif [[ "$num" -ge "$warn" ]]; then
        local wa="POWERKIT_PLUGIN_${upper}_WARNING_ACCENT_COLOR"
        local wi="POWERKIT_PLUGIN_${upper}_WARNING_ACCENT_COLOR_ICON"
        printf '%s:%s' "${!wa:-$accent}" "${!wi:-$accent_icon}"
    else
        printf '%s:%s' "$accent" "$accent_icon"
    fi
}

# Clean content (remove status prefixes)
clean_content() {
    local c="$1"
    [[ "$c" =~ ^[a-z]+: ]] && c="${c#*:}"
    printf '%s' "${c#MODIFIED:}"
}

# Pad icon to fixed width with space before and after
pad_icon() {
    printf '%-1s ' "$1"
}

# Pad separator to fixed width
pad_separator() {
    printf '%-1s' "$1"
}

# =============================================================================
# Main
# =============================================================================

declare -a NAMES=() CONTENTS=() ACCENTS=() ACCENT_ICONS=() ICONS=()

IFS=';' read -ra CONFIGS <<< "$PLUGINS_CONFIG"

for config in "${CONFIGS[@]}"; do
    [[ -z "$config" ]] && continue
    
    IFS=':' read -r name cfg_accent cfg_accent_icon cfg_icon plugin_type <<< "$config"
    
    plugin_script="${CURRENT_DIR}/plugin/${name}.sh"
    [[ ! -f "$plugin_script" ]] && continue
    
    # Clean previous plugin
    unset -f load_plugin plugin_get_display_info 2>/dev/null || true
    
    # Source plugin (bootstrap cached via guards)
    # shellcheck source=/dev/null
    . "$plugin_script" 2>/dev/null || continue
    
    # Get content
    content=""
    declare -f load_plugin &>/dev/null && content=$(load_plugin 2>/dev/null) || true
    
    # Skip conditional without content
    [[ "$plugin_type" == "conditional" && -z "$content" ]] && continue
    
    # Get defaults if not in config
    if [[ -z "$cfg_accent" || -z "$cfg_accent_icon" ]]; then
        IFS=':' read -r def_accent def_accent_icon def_icon <<< "$(get_plugin_defaults "$name")"
        [[ -z "$cfg_accent" ]] && cfg_accent="$def_accent"
        [[ -z "$cfg_accent_icon" ]] && cfg_accent_icon="$def_accent_icon"
        [[ -z "$cfg_icon" ]] && cfg_icon="$def_icon"
    fi
    
    # Check plugin's custom display info
    if declare -f plugin_get_display_info &>/dev/null; then
        IFS=':' read -r show ov_accent ov_accent_icon ov_icon <<< "$(plugin_get_display_info "${content,,}")"
        [[ "$show" == "0" ]] && continue
        [[ -n "$ov_accent" ]] && cfg_accent="$ov_accent"
        [[ -n "$ov_accent_icon" ]] && cfg_accent_icon="$ov_accent_icon"
        [[ -n "$ov_icon" ]] && cfg_icon="$ov_icon"
    fi
    
    # Apply thresholds
    IFS=':' read -r cfg_accent cfg_accent_icon <<< "$(apply_thresholds "$name" "$content" "$cfg_accent" "$cfg_accent_icon")"
    
    # Resolve to hex
    cfg_accent=$(get_color "$cfg_accent")
    cfg_accent_icon=$(get_color "$cfg_accent_icon")
    
    NAMES+=("$name")
    CONTENTS+=("$(clean_content "$content")")
    ACCENTS+=("$cfg_accent")
    ACCENT_ICONS+=("$cfg_accent_icon")
    ICONS+=("$cfg_icon")
done

# =============================================================================
# Render
# =============================================================================

total=${#NAMES[@]}
[[ $total -eq 0 ]] && exit 0

output=""
prev_accent=""

# Pre-compute padded separators
RIGHT_SEP=$(pad_separator "$RIGHT_SEPARATOR")
RIGHT_SEP_INV=$(pad_separator "$RIGHT_SEPARATOR_INVERSE")

for ((i=0; i<total; i++)); do
    content="${CONTENTS[$i]}"
    accent="${ACCENTS[$i]}"
    accent_icon="${ACCENT_ICONS[$i]}"
    icon=$(pad_icon "${ICONS[$i]}")
    
    # Separators
    if [[ $i -eq 0 ]]; then
        if [[ "$TRANSPARENT" == "true" ]]; then
            sep_start="#[fg=${accent_icon},bg=default]${RIGHT_SEP}#[none]"
        else
            sep_start="#[fg=${STATUS_BG},bg=${accent_icon}]${RIGHT_SEP}#[none]"
        fi
    else
        sep_start="#[fg=${prev_accent},bg=${accent_icon}]${RIGHT_SEP}#[none]"
    fi
    
    sep_mid="#[fg=${accent_icon},bg=${accent}]${RIGHT_SEP}#[none]"
    
    # Build output - icon with fixed width padding
    output+="${sep_start}#[fg=${TEXT_COLOR},bg=${accent_icon},bold]${icon}${sep_mid}"
    
    if [[ $i -eq $((total-1)) ]]; then
        output+="#[fg=${TEXT_COLOR},bg=${accent}] ${content} "
    else
        output+="#[fg=${TEXT_COLOR},bg=${accent}] ${content} #[none]"
        [[ "$TRANSPARENT" == "true" ]] && output+="#[fg=${accent},bg=default]${RIGHT_SEP_INV}#[bg=default]"
    fi
    
    prev_accent="$accent"
done

printf '%s' "$output"
