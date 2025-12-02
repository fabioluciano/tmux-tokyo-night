#!/usr/bin/env bash
# =============================================================================
# Plugin: audio
# Description: Display audio input/output devices with interactive selection
# Dependencies: pactl/pamixer (Linux), SwitchAudioSource (macOS)
# =============================================================================
#
# Configuration options:
#   @theme_plugin_audio_show               - What to show: input|output|both|off (default: off)
#   @theme_plugin_audio_input_icon         - Input device icon (default: 🎤)
#   @theme_plugin_audio_output_icon        - Output device icon (default: 🔊)
#   @theme_plugin_audio_separator          - Separator between input/output (default:  | )
#   @theme_plugin_audio_accent_color       - Default accent color
#   @theme_plugin_audio_accent_color_icon  - Default icon accent color
#   @theme_plugin_audio_cache_ttl          - Cache time in seconds (default: 5)
#   @theme_plugin_audio_max_length         - Maximum device name length (default: 15)
#   @theme_plugin_audio_input_key          - Keybinding for input selection (default: I)
#   @theme_plugin_audio_output_key         - Keybinding for output selection (default: O)
#
# Example configurations:
#   # Show both devices in status bar
#   set -g @theme_plugin_audio_show "both"
#   
#   # Show only input device
#   set -g @theme_plugin_audio_show "input"
#   
#   # Don't show in status bar but keep keybindings active
#   set -g @theme_plugin_audio_show "off"
#   
#   # Custom icons and separator
#   set -g @theme_plugin_audio_input_icon "🎙️"
#   set -g @theme_plugin_audio_output_icon "🎧"
#   set -g @theme_plugin_audio_separator " • "
#   
#   # Custom keybindings
#   set -g @theme_plugin_audio_input_key "M"
#   set -g @theme_plugin_audio_output_key "S"
#
# =============================================================================

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck source=src/defaults.sh
. "$ROOT_DIR/../defaults.sh"
# shellcheck source=src/utils.sh
. "$ROOT_DIR/../utils.sh"

# =============================================================================
# Plugin Configuration
# =============================================================================

# Get plugin options with defaults
get_plugin_option() {
    local option="$1"
    local default="$2"
    get_tmux_option "@theme_plugin_audiodevices_$option" "$default"
}

# Plugin variables for theme system
# shellcheck disable=SC2034
plugin_audiodevices_icon=$(get_plugin_option "icon" "${THEME_DEFAULT_PLUGIN_AUDIODEVICES_ICON}")
# shellcheck disable=SC2034
plugin_audiodevices_accent_color=$(get_plugin_option "accent_color" "${PLUGIN_AUDIODEVICES_ACCENT_COLOR}")
# shellcheck disable=SC2034
plugin_audiodevices_accent_color_icon=$(get_plugin_option "accent_color_icon" "${PLUGIN_AUDIODEVICES_ACCENT_COLOR_ICON}")

export plugin_audiodevices_icon plugin_audiodevices_accent_color plugin_audiodevices_accent_color_icon

# =============================================================================
# Plugin Interface Implementation
# =============================================================================

# Function to inform the plugin type to the renderer
plugin_get_type() {
    printf 'static'
}

# Plugin settings
PLUGIN_SHOW=$(get_plugin_option "show" "${THEME_DEFAULT_PLUGIN_AUDIODEVICES_SHOW:-off}")
PLUGIN_INPUT_ICON=$(get_plugin_option "input_icon" "${THEME_DEFAULT_PLUGIN_AUDIODEVICES_INPUT_ICON:-🎤}")
PLUGIN_OUTPUT_ICON=$(get_plugin_option "output_icon" "${THEME_DEFAULT_PLUGIN_AUDIODEVICES_OUTPUT_ICON:-🔊}")
PLUGIN_SEPARATOR=$(get_plugin_option "separator" "${THEME_DEFAULT_PLUGIN_AUDIODEVICES_SEPARATOR:- | }")
PLUGIN_ACCENT_COLOR=$(get_plugin_option "accent_color" "${PLUGIN_AUDIODEVICES_ACCENT_COLOR:-blue7}")
PLUGIN_ACCENT_COLOR_ICON=$(get_plugin_option "accent_color_icon" "${PLUGIN_AUDIODEVICES_ACCENT_COLOR_ICON:-blue0}")
PLUGIN_CACHE_TTL=$(get_plugin_option "cache_ttl" "${THEME_DEFAULT_PLUGIN_AUDIODEVICES_CACHE_TTL:-5}")
PLUGIN_MAX_LENGTH=$(get_plugin_option "max_length" "${THEME_DEFAULT_PLUGIN_AUDIODEVICES_MAX_LENGTH:-15}")

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
            # Single pactl call to get current source with description
            pactl list sources 2>/dev/null | awk -v default="$(pactl get-default-source 2>/dev/null)" '
                /^Source #/ {in_source=1; description=""; name=""}
                in_source && /Name:/ {name=$2}
                in_source && /Description:/ {$1=""; description=substr($0,2)}
                in_source && /^$/ {
                    if (name == default && description != "") {
                        print description
                        exit
                    }
                    in_source=0
                }
                END {if (description == "") print "No Input"}
            '
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
            # Single pactl call to get current sink with description
            pactl list sinks 2>/dev/null | awk -v default="$(pactl get-default-sink 2>/dev/null)" '
                /^Sink #/ {in_sink=1; description=""; name=""}
                in_sink && /Name:/ {name=$2}
                in_sink && /Description:/ {$1=""; description=substr($0,2)}
                in_sink && /^$/ {
                    if (name == default && description != "") {
                        print description
                        exit
                    }
                    in_sink=0
                }
                END {if (description == "") print "No Output"}
            '
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

get_cache_file() {
    local cache_type="$1"
    echo "/tmp/tmux_audiodevices_${cache_type}_$$"
}

is_cache_valid() {
    local cache_file="$1"
    local ttl="$2"
    
    if [[ -f "$cache_file" ]]; then
        local cache_time current_time
        cache_time=$(stat -c %Y "$cache_file" 2>/dev/null || stat -f %m "$cache_file" 2>/dev/null || echo 0)
        current_time=$(date +%s)
        
        if [[ $((current_time - cache_time)) -lt $ttl ]]; then
            return 0
        fi
    fi
    return 1
}

get_cached_or_fetch() {
    local cache_type="$1"
    local cache_file
    cache_file=$(get_cache_file "$cache_type")
    
    if is_cache_valid "$cache_file" "$PLUGIN_CACHE_TTL"; then
        cat "$cache_file"
    else
        local result
        if [[ "$cache_type" == "input" ]]; then
            result=$(get_current_input_device)
        else
            result=$(get_current_output_device)
        fi
        
        echo "$result" > "$cache_file"
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
    local selector_script="$ROOT_DIR/../helpers/audio_device_selector.sh"
    
    # Set up input device keybinding
    if [[ -n "$PLUGIN_INPUT_KEY" ]]; then
        tmux bind-key "$PLUGIN_INPUT_KEY" run-shell "'$selector_script' input"
    fi
    
    # Set up output device keybinding  
    if [[ -n "$PLUGIN_OUTPUT_KEY" ]]; then
        tmux bind-key "$PLUGIN_OUTPUT_KEY" run-shell "'$selector_script' output"
    fi
}

# =============================================================================
# Plugin Display Info for Render System
# =============================================================================

# This function is called by render_plugins.sh to get display decisions
# Output format: "show:accent:accent_icon:icon"
plugin_get_display_info() {
    local _content="$1"
    
    # Check if plugin should be shown based on configuration
    if [[ "$PLUGIN_SHOW" == "off" ]]; then
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
    [[ "$PLUGIN_SHOW" == "off" ]] && return
    
    # Return empty if audio system is not supported
    local audio_system
    audio_system=$(detect_audio_system)
    [[ "$audio_system" == "none" ]] && return
    
    local input_device output_device display_parts=()
    
    # Get device information based on what should be shown
    case "$PLUGIN_SHOW" in
        "input"|"both")
            input_device=$(get_cached_or_fetch "input")
            input_device=$(truncate_device_name "$input_device" "$PLUGIN_MAX_LENGTH")
            ;;
    esac
    
    case "$PLUGIN_SHOW" in
        "output"|"both")
            output_device=$(get_cached_or_fetch "output")
            output_device=$(truncate_device_name "$output_device" "$PLUGIN_MAX_LENGTH")
            ;;
    esac
    
    # Build display string
    case "$PLUGIN_SHOW" in
        "input")
            if [[ -n "$input_device" ]]; then
                display_parts+=("#[fg=$PLUGIN_ACCENT_COLOR_ICON]${PLUGIN_INPUT_ICON} #[fg=$PLUGIN_ACCENT_COLOR]$input_device")
            fi
            ;;
        "output")
            if [[ -n "$output_device" ]]; then
                display_parts+=("#[fg=$PLUGIN_ACCENT_COLOR_ICON]${PLUGIN_OUTPUT_ICON} #[fg=$PLUGIN_ACCENT_COLOR]$output_device")
            fi
            ;;
        "both")
            if [[ -n "$input_device" ]]; then
                display_parts+=("#[fg=$PLUGIN_ACCENT_COLOR_ICON]${PLUGIN_INPUT_ICON} #[fg=$PLUGIN_ACCENT_COLOR]$input_device")
            fi
            if [[ -n "$output_device" ]]; then
                display_parts+=("#[fg=$PLUGIN_ACCENT_COLOR_ICON]${PLUGIN_OUTPUT_ICON} #[fg=$PLUGIN_ACCENT_COLOR]$output_device")
            fi
            ;;
    esac
    
    # Join parts with separator and output
    if [[ ${#display_parts[@]} -gt 0 ]]; then
        local IFS="$PLUGIN_SEPARATOR"
        echo "${display_parts[*]}"
    fi
}

# Only run if executed directly (not sourced)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    load_plugin
fi