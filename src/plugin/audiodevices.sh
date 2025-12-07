#!/usr/bin/env bash
# Audio devices plugin with interactive selection
# Dependencies: pactl/pamixer (Linux), SwitchAudioSource (macOS)

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck source=src/plugin_bootstrap.sh
. "$ROOT_DIR/../plugin_bootstrap.sh"

# =============================================================================
# Plugin Configuration
# =============================================================================

# Initialize cache (DRY - sets CACHE_KEY and CACHE_TTL automatically)
plugin_init "audiodevices"

# =============================================================================
# Plugin Interface Implementation
# =============================================================================

# Function to inform the plugin type to the renderer
plugin_get_type() {
    printf 'static'
}

# Plugin settings
PLUGIN_SHOW=$(get_plugin_option "show" "$THEME_DEFAULT_PLUGIN_AUDIODEVICES_SHOW")
PLUGIN_INPUT_ICON=$(get_plugin_option "input_icon" "$THEME_DEFAULT_PLUGIN_AUDIODEVICES_INPUT_ICON")
PLUGIN_OUTPUT_ICON=$(get_plugin_option "output_icon" "$THEME_DEFAULT_PLUGIN_AUDIODEVICES_OUTPUT_ICON")
PLUGIN_SEPARATOR=$(get_plugin_option "separator" "$THEME_DEFAULT_PLUGIN_AUDIODEVICES_SEPARATOR")
PLUGIN_ACCENT_COLOR=$(get_plugin_option "accent_color" "$POWERKIT_PLUGIN_AUDIODEVICES_ACCENT_COLOR")
PLUGIN_ACCENT_COLOR_ICON=$(get_plugin_option "accent_color_icon" "$POWERKIT_PLUGIN_AUDIODEVICES_ACCENT_COLOR_ICON")
PLUGIN_CACHE_TTL=$(get_plugin_option "cache_ttl" "$THEME_DEFAULT_PLUGIN_AUDIODEVICES_CACHE_TTL")
PLUGIN_MAX_LENGTH=$(get_plugin_option "max_length" "$THEME_DEFAULT_PLUGIN_AUDIODEVICES_MAX_LENGTH")

# Keybinding settings
PLUGIN_INPUT_KEY=$(get_plugin_option "input_key" "${THEME_DEFAULT_PLUGIN_AUDIODEVICES_INPUT_KEY:-I}")
PLUGIN_OUTPUT_KEY=$(get_plugin_option "output_key" "${THEME_DEFAULT_PLUGIN_AUDIODEVICES_OUTPUT_KEY:-O}")

# =============================================================================
# Audio System Detection
# =============================================================================



detect_audio_system() {
    # Setup proper environment for audio tools
    if [[ "$OSTYPE" == "darwin"* ]]; then
        if command -v SwitchAudioSource &> /dev/null; then
            echo "macos"
        else
            echo "none"
        fi
    else
        # Linux - ensure proper PulseAudio environment
        export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
        export PULSE_RUNTIME_PATH="${PULSE_RUNTIME_PATH:-/run/user/$(id -u)/pulse}"
        
        if command -v pactl &> /dev/null; then
            echo "linux"
        else
            echo "none"
        fi
    fi
}

# =============================================================================
# Device Information Retrieval
# =============================================================================

get_current_input_device() {
    local audio_system
    audio_system=$(detect_audio_system)
    
    case "$audio_system" in
        "linux")
            local default_source
            default_source=$(pactl get-default-source 2>/dev/null)
            if [[ -n "$default_source" ]]; then
                # Get description from source info
                local description
                description=$(pactl list sources 2>/dev/null | grep -A 20 "Name: $default_source" | grep "Description:" | cut -d: -f2- | sed 's/^ *//')
                if [[ -n "$description" ]]; then
                    echo "$description"
                else
                    # Fallback to simplified name
                    echo "${default_source##*.}" | tr '_' ' '
                fi
            else
                echo "No Input"
            fi
            ;;
        "macos")
            SwitchAudioSource -c -t input 2>/dev/null || echo "No Input"
            ;;
        *)
            echo "Unsupported"
            ;;
    esac
}

get_current_output_device() {
    local audio_system
    audio_system=$(detect_audio_system)
    
    case "$audio_system" in
        "linux")
            local default_sink
            default_sink=$(pactl get-default-sink 2>/dev/null)
            if [[ -n "$default_sink" ]]; then
                # Get description from sink info
                local description
                description=$(pactl list sinks 2>/dev/null | grep -A 20 "Name: $default_sink" | grep "Description:" | cut -d: -f2- | sed 's/^ *//')
                if [[ -n "$description" ]]; then
                    echo "$description"
                else
                    # Fallback to simplified name
                    echo "${default_sink##*.}" | tr '_' ' '
                fi
            else
                echo "No Output"
            fi
            ;;
        "macos")
            SwitchAudioSource -c -t output 2>/dev/null || echo "No Output"
            ;;
        *)
            echo "Unsupported"
            ;;
    esac
}

# =============================================================================
# Text Formatting
# =============================================================================

truncate_device_name() {
    local device_name="$1"
    local max_length="$2"
    
    if [[ ${#device_name} -gt $max_length ]]; then
        echo "${device_name:0:$((max_length-3))}..."
    else
        echo "$device_name"
    fi
}

# =============================================================================
# Cache Management
# =============================================================================

get_cached_or_fetch() {
    local cache_type="$1"
    local cache_key="${CACHE_KEY}_${cache_type}"
    local cached_value
    
    if cached_value=$(cache_get "$cache_key" "$CACHE_TTL"); then
        echo "$cached_value"
    else
        local result
        if [[ "$cache_type" == "input" ]]; then
            result=$(get_current_input_device)
        else
            result=$(get_current_output_device)
        fi
        
        cache_set "$cache_key" "$result"
        echo "$result"
    fi
}

# =============================================================================
# Plugin Display
# =============================================================================



# =============================================================================
# Keybinding Setup
# =============================================================================

setup_keybindings() {
    # Only setup keybindings if the plugin is active (not "off")
    if [[ "$POWERKIT_PLUGIN_AUDIODEVICES_SHOW" == "off" ]]; then
        return
    fi
    
    local selector_script="$ROOT_DIR/../helpers/audio_device_selector.sh"
    
    # Set up input device keybinding
    if [[ -n "$POWERKIT_PLUGIN_INPUT_KEY" ]]; then
        tmux bind-key "$POWERKIT_PLUGIN_INPUT_KEY" run-shell "'$selector_script' input"
    fi
    
    # Set up output device keybinding  
    if [[ -n "$POWERKIT_PLUGIN_OUTPUT_KEY" ]]; then
        tmux bind-key "$POWERKIT_PLUGIN_OUTPUT_KEY" run-shell "'$selector_script' output"
    fi
}

# =============================================================================
# Plugin Display Info for Render System
# =============================================================================

# This function is called by plugin_helpers.sh to get display decisions
# Output format: "show:accent:accent_icon:icon"
plugin_get_display_info() {
    local _content="$1"
    
    # Check if plugin should be shown based on configuration
    if [[ "$POWERKIT_PLUGIN_AUDIODEVICES_SHOW" == "off" ]]; then
        echo "0:::"
        return
    fi
    
    # Show plugin with configured colors and icon
    echo "1:::"
}

# =============================================================================
# Main Plugin Entry Points
# =============================================================================

# =============================================================================
# Plugin Entry Point
# =============================================================================

load_plugin() {
    # Return empty if plugin is disabled
    [[ "$POWERKIT_PLUGIN_AUDIODEVICES_SHOW" == "off" ]] && return
    
    # Return empty if audio system is not supported
    local audio_system
    audio_system=$(detect_audio_system)
    [[ "$audio_system" == "none" ]] && return
    
    local input_device output_device display_parts=()
    
    # Get device information based on what should be shown
    case "$POWERKIT_PLUGIN_AUDIODEVICES_SHOW" in
        "input"|"both")
            input_device=$(get_cached_or_fetch "input")
            input_device=$(truncate_device_name "$input_device" "$POWERKIT_PLUGIN_MAX_LENGTH")
            ;;
    esac
    
    case "$POWERKIT_PLUGIN_AUDIODEVICES_SHOW" in
        "output"|"both")
            output_device=$(get_cached_or_fetch "output")
            output_device=$(truncate_device_name "$output_device" "$POWERKIT_PLUGIN_MAX_LENGTH")
            ;;
    esac
    
    # Build display string
    case "$POWERKIT_PLUGIN_AUDIODEVICES_SHOW" in
        "input")
            if [[ -n "$input_device" ]]; then
                display_parts+=("#[fg=$POWERKIT_PLUGIN_ACCENT_COLOR_ICON]${PLUGIN_INPUT_ICON} #[fg=$POWERKIT_PLUGIN_ACCENT_COLOR]$input_device")
            fi
            ;;
        "output")
            if [[ -n "$output_device" ]]; then
                display_parts+=("#[fg=$POWERKIT_PLUGIN_ACCENT_COLOR_ICON]${PLUGIN_OUTPUT_ICON} #[fg=$POWERKIT_PLUGIN_ACCENT_COLOR]$output_device")
            fi
            ;;
        "both")
            if [[ -n "$input_device" ]]; then
                display_parts+=("#[fg=$POWERKIT_PLUGIN_ACCENT_COLOR_ICON]${PLUGIN_INPUT_ICON} #[fg=$POWERKIT_PLUGIN_ACCENT_COLOR]$input_device")
            fi
            if [[ -n "$output_device" ]]; then
                display_parts+=("#[fg=$POWERKIT_PLUGIN_ACCENT_COLOR_ICON]${PLUGIN_OUTPUT_ICON} #[fg=$POWERKIT_PLUGIN_ACCENT_COLOR]$output_device")
            fi
            ;;
    esac
    
    # Join parts with separator and output
    if [[ ${#display_parts[@]} -gt 0 ]]; then
        local IFS="$POWERKIT_PLUGIN_SEPARATOR"
        echo "${display_parts[*]}"
    fi
}

# Only run if executed directly (not sourced)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    load_plugin
fi