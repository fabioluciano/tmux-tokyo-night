#!/usr/bin/env bash
# =============================================================================  
# Audio Device Selectors for tmux Tokyo Night Theme
# Cross-platform audio device selector supporting PulseAudio, PipeWire, and macOS
# =============================================================================

set -euo pipefail

# =============================================================================
# Audio System Detection & Input Selection
# =============================================================================

select_input_device() {
    local audio_system=""
    local current_input=""
    local -a menu_items=()
    local -a device_names=()
    
    # Detect audio system and get devices
    if [[ "$OSTYPE" == "darwin"* ]]; then
        if command -v SwitchAudioSource &> /dev/null; then
            audio_system="macos"
            current_input=$(SwitchAudioSource -c -t input 2>/dev/null || echo "")
            
            while IFS= read -r device; do
                [[ -z "$device" ]] && continue
                local marker=" "
                [[ "$device" == "$current_input" ]] && marker="●"
                menu_items+=("$marker $device")
                device_names+=("$device")
            done < <(SwitchAudioSource -a -t input 2>/dev/null)
        else
            tmux display-message "❌ Install SwitchAudioSource: brew install switchaudio-osx"
            return 1
        fi
    elif command -v pactl &> /dev/null; then
        audio_system="linux"
        current_input=$(pactl get-default-source 2>/dev/null || echo "")
        
        while IFS=$'\t' read -r index name driver sample_spec state; do
            [[ "$name" == *.monitor ]] && continue
            
            # Get description
            local description=""
            description=$(pactl list sources | grep -A 30 "Source #$index" | grep -E "(Description|device\.description)" | head -1 | sed -n 's/.*Description: \(.*\)/\1/p; s/.*device\.description = "\([^"]*\)".*/\1/p')
            
            [[ -z "$description" ]] && description=$(echo "$name" | sed 's/alsa_input\.//; s/\.analog-stereo//; s/_/ /g')
            
            local marker=" "
            [[ "$name" == "$current_input" ]] && marker="●"
            
            menu_items+=("$marker $description")
            device_names+=("$name")
        done < <(pactl list short sources 2>/dev/null)
    else
        tmux display-message "❌ No supported audio system found (pactl/SwitchAudioSource)"
        return 1
    fi
    
    if [[ ${#menu_items[@]} -eq 0 ]]; then
        tmux display-message "❌ No input devices found"
        return 1
    fi
    
    # Create tmux menu
    local -a menu_args=()
    for i in "${!menu_items[@]}"; do
        local item="${menu_items[$i]}"
        local name="${device_names[$i]}"
        local clean_desc="${item#* }"
        
        if [[ "$audio_system" == "linux" ]]; then
            menu_args+=("$item" "" "run-shell \"pactl set-default-source '$name' && tmux display-message '🎤 Input: $clean_desc'\"")
        else
            menu_args+=("$item" "" "run-shell \"SwitchAudioSource -s '$name' -t input && tmux display-message '🎤 Input: $clean_desc'\"")
        fi
    done
    
    tmux display-menu -T "🎤 Select Input Device" -x C -y C "${menu_args[@]}"
}

# =============================================================================
# Output Device Selection
# =============================================================================

select_output_device() {
    local audio_system=""
    local current_output=""
    local -a menu_items=()
    local -a device_names=()
    
    # Detect audio system and get devices
    if [[ "$OSTYPE" == "darwin"* ]]; then
        if command -v SwitchAudioSource &> /dev/null; then
            audio_system="macos"
            current_output=$(SwitchAudioSource -c -t output 2>/dev/null || echo "")
            
            while IFS= read -r device; do
                [[ -z "$device" ]] && continue
                local marker=" "
                [[ "$device" == "$current_output" ]] && marker="●"
                menu_items+=("$marker $device")
                device_names+=("$device")
            done < <(SwitchAudioSource -a -t output 2>/dev/null)
        else
            tmux display-message "❌ Install SwitchAudioSource: brew install switchaudio-osx"
            return 1
        fi
    elif command -v pactl &> /dev/null; then
        audio_system="linux"
        current_output=$(pactl get-default-sink 2>/dev/null || echo "")
        
        while IFS=$'\t' read -r index name driver sample_spec state; do
            # Get description
            local description=""
            description=$(pactl list sinks | grep -A 30 "Sink #$index" | grep -E "(Description|device\.description)" | head -1 | sed -n 's/.*Description: \(.*\)/\1/p; s/.*device\.description = "\([^"]*\)".*/\1/p')
            
            [[ -z "$description" ]] && description=$(echo "$name" | sed 's/alsa_output\.//; s/\.analog-stereo//; s/\.hdmi-stereo//; s/_/ /g; s/pci-0000://; s/usb-//; s/\.0-00//g')
            
            local marker=" "
            [[ "$name" == "$current_output" ]] && marker="●"
            
            menu_items+=("$marker $description")
            device_names+=("$name")
        done < <(pactl list short sinks 2>/dev/null)
    else
        tmux display-message "❌ No supported audio system found (pactl/SwitchAudioSource)"
        return 1
    fi
    
    if [[ ${#menu_items[@]} -eq 0 ]]; then
        tmux display-message "❌ No output devices found"
        return 1
    fi
    
    # Create tmux menu
    local -a menu_args=()
    for i in "${!menu_items[@]}"; do
        local item="${menu_items[$i]}"
        local name="${device_names[$i]}"
        local clean_desc="${item#* }"
        
        if [[ "$audio_system" == "linux" ]]; then
            menu_args+=("$item" "" "run-shell \"pactl set-default-sink '$name' && tmux display-message '🔊 Output: $clean_desc'\"")
        else
            menu_args+=("$item" "" "run-shell \"SwitchAudioSource -s '$name' -t output && tmux display-message '🔊 Output: $clean_desc'\"")
        fi
    done
    
    tmux display-menu -T "🔊 Select Output Device" -x C -y C "${menu_args[@]}"
}

# =============================================================================
# Main
# =============================================================================

case "${1:-}" in
    "input"|"mic"|"microphone")
        select_input_device
        ;;
    "output"|"speaker"|"speakers")
        select_output_device
        ;;
    *)
        echo "Usage: $0 {input|output}"
        echo "  input  - Select microphone/input device"
        echo "  output - Select speakers/output device"
        echo ""
        echo "Cross-platform audio device selector"
        echo "Supports: PulseAudio, PipeWire (Linux), macOS with SwitchAudioSource"
        exit 1
        ;;
esac