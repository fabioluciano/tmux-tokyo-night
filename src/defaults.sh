#!/usr/bin/env bash
# =============================================================================
# PowerKit Defaults Configuration
# =============================================================================
# This file contains all default values for PowerKit plugins and core features.
# Uses semantic color names that work across different themes.
# Users can override any option in their tmux.conf.
#
# Usage: These defaults are applied when PowerKit loads. User configurations
#        in tmux.conf take precedence over these defaults.
#
# To use in a plugin:
#   1. Source this file: . "$ROOT_DIR/../defaults.sh"
#   2. Use variables like: $(get_tmux_option "@powerkit_plugin_X_icon" "$POWERKIT_PLUGIN_X_ICON")
# =============================================================================

# shellcheck disable=SC2034
# All variables in this file are intentionally exported for use by other scripts
# that source this file. ShellCheck cannot track cross-file variable usage.

# Prevent multiple sourcing
[[ -n "${_DEFAULTS_LOADED:-}" ]] && return 0
_DEFAULTS_LOADED=1

# =============================================================================
# Helper: Get default for a PowerKit plugin option
# Usage: get_powerkit_plugin_default "battery" "icon" -> returns $POWERKIT_PLUGIN_BATTERY_ICON
# =============================================================================
get_powerkit_plugin_default() {
    local plugin_name="${1^^}"  # uppercase
    local option_name="${2^^}"  # uppercase
    plugin_name="${plugin_name//-/_}"  # replace - with _
    option_name="${option_name//-/_}"  # replace - with _
    local var_name="POWERKIT_PLUGIN_${plugin_name}_${option_name}"
    printf '%s' "${!var_name:-}"
}

# PowerKit plugin configuration function
get_plugin_default() {
    get_powerkit_plugin_default "$@"
}

# =============================================================================
# POWERKIT CORE OPTIONS
# =============================================================================

# Theme family (e.g., tokyo-night, dracula, nord)
POWERKIT_DEFAULT_THEME_FAMILY="tokyo-night"

# Theme variant (e.g., night, storm, day, moon - if empty, uses first available)
POWERKIT_DEFAULT_THEME_VARIANT="night"

# Disable all plugins: 0 = enabled, 1 = disabled
POWERKIT_DEFAULT_DISABLE_PLUGINS=0

# Status bar layout: single, dual
POWERKIT_DEFAULT_BAR_LAYOUT="single"

# Transparent status bar: true, false
POWERKIT_DEFAULT_TRANSPARENT="false"

# Default plugins to enable (comma-separated)
POWERKIT_DEFAULT_PLUGINS="datetime,hostname,git,battery,cpu,memory"

# Status bar lengths
POWERKIT_DEFAULT_STATUS_LEFT_LENGTH="100"
POWERKIT_DEFAULT_STATUS_RIGHT_LENGTH="1000"

# =============================================================================
# SEPARATORS
# =============================================================================

# Powerline separators (Unicode characters)
POWERKIT_DEFAULT_LEFT_SEPARATOR=$'\ue0bc'
POWERKIT_DEFAULT_RIGHT_SEPARATOR=$'\ue0b2'

# Inverse separators for transparent mode
POWERKIT_DEFAULT_LEFT_SEPARATOR_INVERSE=$'\ue0d4'
POWERKIT_DEFAULT_RIGHT_SEPARATOR_INVERSE=$'\ue0d6'


# =============================================================================
# SESSION & WINDOW ICONS
# =============================================================================

# Auto-detect OS icon if not explicitly set
# Users can override by setting @powerkit_session_icon manually
POWERKIT_DEFAULT_SESSION_ICON="auto"
POWERKIT_DEFAULT_ACTIVE_WINDOW_ICON=""
POWERKIT_DEFAULT_INACTIVE_WINDOW_ICON=""
POWERKIT_DEFAULT_ZOOMED_WINDOW_ICON=""
POWERKIT_DEFAULT_PANE_SYNCHRONIZED_ICON="✵"

# =============================================================================
# WINDOW TITLES & STYLES
# =============================================================================

POWERKIT_DEFAULT_ACTIVE_WINDOW_TITLE="#W "
POWERKIT_DEFAULT_INACTIVE_WINDOW_TITLE="#W "

# Style for windows with activity: italics, bold, none, etc.
POWERKIT_DEFAULT_WINDOW_WITH_ACTIVITY_STYLE="italics"

# Active window colors (using semantic color names)
POWERKIT_DEFAULT_ACTIVE_WINDOW_NUMBER_BG="accent"
POWERKIT_DEFAULT_ACTIVE_WINDOW_CONTENT_BG="primary"

# Style for bell status
POWERKIT_DEFAULT_STATUS_BELL_STYLE="bold"

# =============================================================================
# POWERKIT HELPER KEYBINDINGS
# =============================================================================

# Key to open PowerKit options reference popup (prefix + key)
# Set to empty string to disable
POWERKIT_DEFAULT_HELPER_KEY="?"
POWERKIT_DEFAULT_HELPER_WIDTH="80%"
POWERKIT_DEFAULT_HELPER_HEIGHT="80%"

# Key to open keybindings viewer popup (prefix + key)
# Set to empty string to disable
POWERKIT_DEFAULT_KEYBINDINGS_KEY="B"
POWERKIT_DEFAULT_KEYBINDINGS_WIDTH="80%"
POWERKIT_DEFAULT_KEYBINDINGS_HEIGHT="80%"

# =============================================================================
# PLUGIN: audiodevices
# =============================================================================
# Audio device plugin - shows current input/output devices and provides keybindings

POWERKIT_PLUGIN_AUDIODEVICES_SHOW="both"                   # off|input|output|both
POWERKIT_PLUGIN_AUDIODEVICES_ICON=$'\uf0ec'  
POWERKIT_PLUGIN_AUDIODEVICES_INPUT_ICON=$'\uec1c'               # Input device icon
POWERKIT_PLUGIN_AUDIODEVICES_OUTPUT_ICON=$'\uf027'              # Output device icon  
POWERKIT_PLUGIN_AUDIODEVICES_SEPARATOR=" | "               # Separator between devices
POWERKIT_PLUGIN_AUDIODEVICES_CACHE_TTL="8"                 # Cache time in seconds
POWERKIT_PLUGIN_AUDIODEVICES_MAX_LENGTH="15"               # Max device name length
POWERKIT_PLUGIN_AUDIODEVICES_INPUT_KEY="J"                 # Input selection key (prefix + key)
POWERKIT_PLUGIN_AUDIODEVICES_OUTPUT_KEY="O"                # Output selection key (prefix + key)
POWERKIT_PLUGIN_AUDIODEVICES_ACCENT_COLOR="info"
POWERKIT_PLUGIN_AUDIODEVICES_ACCENT_COLOR_ICON="info"

# =============================================================================
# PLUGIN: camera
# =============================================================================
# Camera status plugin - shows when camera is active/inactive

POWERKIT_PLUGIN_CAMERA_SHOW="on"                          # on|off
POWERKIT_PLUGIN_CAMERA_ICON=$'\uf030'                         # Camera icon when inactive  
POWERKIT_PLUGIN_CAMERA_CACHE_TTL="1"                      # Cache time in seconds
POWERKIT_PLUGIN_CAMERA_SHOW_WHEN_INACTIVE="false"         # Show when camera is off
POWERKIT_PLUGIN_CAMERA_ACCENT_COLOR="info"
POWERKIT_PLUGIN_CAMERA_ACCENT_COLOR_ICON="info"

# Camera active colors (when camera is on)
POWERKIT_PLUGIN_CAMERA_ACTIVE_ACCENT_COLOR="error"
POWERKIT_PLUGIN_CAMERA_ACTIVE_ACCENT_COLOR_ICON="error"

# =============================================================================
# PLUGIN: microphone
# =============================================================================

POWERKIT_PLUGIN_MICROPHONE_ICON=$'\ued03'
POWERKIT_PLUGIN_MICROPHONE_MUTED_ICON=$'\uefc6'
POWERKIT_PLUGIN_MICROPHONE_ACCENT_COLOR="success"
POWERKIT_PLUGIN_MICROPHONE_ACCENT_COLOR_ICON="success"
POWERKIT_PLUGIN_MICROPHONE_CACHE_TTL="1"

# Microphone state-specific colors
POWERKIT_PLUGIN_MICROPHONE_ACTIVE_ACCENT_COLOR="error"
POWERKIT_PLUGIN_MICROPHONE_ACTIVE_ACCENT_COLOR_ICON="error"
POWERKIT_PLUGIN_MICROPHONE_MUTED_ACCENT_COLOR="warning"
POWERKIT_PLUGIN_MICROPHONE_MUTED_ACCENT_COLOR_ICON="warning"

# Microphone mute toggle keybinding  
POWERKIT_PLUGIN_MICROPHONE_MUTE_KEY="m"

# =============================================================================
# PLUGIN: datetime
# =============================================================================

POWERKIT_PLUGIN_DATETIME_ICON="󰥔"
POWERKIT_PLUGIN_DATETIME_ACCENT_COLOR="text-muted"
POWERKIT_PLUGIN_DATETIME_ACCENT_COLOR_ICON="text-muted"

# Format: predefined (time, time-seconds, time-12h, date, date-full, date-iso,
#         datetime, weekday, full, iso) or custom strftime format
POWERKIT_PLUGIN_DATETIME_FORMAT="datetime"

# Secondary timezone (e.g., "America/New_York", "Europe/London", "Asia/Tokyo")
# Leave empty to disable
POWERKIT_PLUGIN_DATETIME_TIMEZONE=""

# Show week number (true/false) - displays "W48" before the date
POWERKIT_PLUGIN_DATETIME_SHOW_WEEK="false"

# Separator between elements (week, date/time, timezone)
POWERKIT_PLUGIN_DATETIME_SEPARATOR=" "

# =============================================================================
# PLUGIN: weather
# =============================================================================

POWERKIT_PLUGIN_WEATHER_ICON="󰥐"
POWERKIT_PLUGIN_WEATHER_ACCENT_COLOR="primary"
POWERKIT_PLUGIN_WEATHER_ACCENT_COLOR_ICON="primary"
POWERKIT_PLUGIN_WEATHER_LOCATION=""
POWERKIT_PLUGIN_WEATHER_UNIT=""
# Format: "compact", "full", "minimal", "detailed", or custom wttr.in format
POWERKIT_PLUGIN_WEATHER_FORMAT="compact"
POWERKIT_PLUGIN_WEATHER_CACHE_TTL="900"

# =============================================================================
# PLUGIN: battery
# =============================================================================

PLUGIN_BATTERY_ICON="󰁹"
PLUGIN_BATTERY_ACCENT_COLOR="blue7"
PLUGIN_BATTERY_ACCENT_COLOR_ICON="blue0"
PLUGIN_BATTERY_CACHE_TTL="45"

# Display mode: percentage (e.g., "85%") or time (e.g., "2:30" remaining)
PLUGIN_BATTERY_DISPLAY_MODE="percentage"

# Battery low threshold settings
PLUGIN_BATTERY_LOW_THRESHOLD="30"
PLUGIN_BATTERY_ICON_LOW="󰂃"
PLUGIN_BATTERY_LOW_ACCENT_COLOR="red"
PLUGIN_BATTERY_LOW_ACCENT_COLOR_ICON="red1"

# Battery warning threshold settings (50%)
PLUGIN_BATTERY_WARNING_THRESHOLD="50"
PLUGIN_BATTERY_WARNING_ACCENT_COLOR="yellow"
PLUGIN_BATTERY_WARNING_ACCENT_COLOR_ICON="orange"

# Battery charging settings
PLUGIN_BATTERY_ICON_CHARGING="󰂄"

# =============================================================================
# PLUGIN: cpu
# =============================================================================

POWERKIT_PLUGIN_CPU_ICON="󰭠"
POWERKIT_PLUGIN_CPU_ACCENT_COLOR="info"
POWERKIT_PLUGIN_CPU_ACCENT_COLOR_ICON="info"
POWERKIT_PLUGIN_CPU_CACHE_TTL="3"

# Threshold settings for dynamic colors
POWERKIT_PLUGIN_CPU_WARNING_THRESHOLD="70"
POWERKIT_PLUGIN_CPU_CRITICAL_THRESHOLD="90"
POWERKIT_PLUGIN_CPU_WARNING_ACCENT_COLOR="warning"
POWERKIT_PLUGIN_CPU_WARNING_ACCENT_COLOR_ICON="warning"
POWERKIT_PLUGIN_CPU_CRITICAL_ACCENT_COLOR="error"
POWERKIT_PLUGIN_CPU_CRITICAL_ACCENT_COLOR_ICON="error"

# =============================================================================
# PLUGIN: memory
# =============================================================================

POWERKIT_PLUGIN_MEMORY_ICON="󰥛"
POWERKIT_PLUGIN_MEMORY_ACCENT_COLOR="primary"
POWERKIT_PLUGIN_MEMORY_ACCENT_COLOR_ICON="primary"
POWERKIT_PLUGIN_MEMORY_FORMAT="percent"
POWERKIT_PLUGIN_MEMORY_CACHE_TTL="5"

# Threshold settings for dynamic colors
POWERKIT_PLUGIN_MEMORY_WARNING_THRESHOLD="70"
POWERKIT_PLUGIN_MEMORY_CRITICAL_THRESHOLD="90"
POWERKIT_PLUGIN_MEMORY_WARNING_ACCENT_COLOR="warning"
POWERKIT_PLUGIN_MEMORY_WARNING_ACCENT_COLOR_ICON="warning"
POWERKIT_PLUGIN_MEMORY_CRITICAL_ACCENT_COLOR="error"
POWERKIT_PLUGIN_MEMORY_CRITICAL_ACCENT_COLOR_ICON="error"

# =============================================================================
# PLUGIN: disk
# =============================================================================

POWERKIT_PLUGIN_DISK_ICON="󰤊"
POWERKIT_PLUGIN_DISK_ACCENT_COLOR="primary"
POWERKIT_PLUGIN_DISK_ACCENT_COLOR_ICON="primary"
POWERKIT_PLUGIN_DISK_MOUNT="/"
POWERKIT_PLUGIN_DISK_FORMAT="percent"
POWERKIT_PLUGIN_DISK_CACHE_TTL="120"

# Threshold settings for dynamic colors
POWERKIT_PLUGIN_DISK_WARNING_THRESHOLD="70"
POWERKIT_PLUGIN_DISK_CRITICAL_THRESHOLD="90"
POWERKIT_PLUGIN_DISK_WARNING_ACCENT_COLOR="warning"
POWERKIT_PLUGIN_DISK_WARNING_ACCENT_COLOR_ICON="warning"
POWERKIT_PLUGIN_DISK_CRITICAL_ACCENT_COLOR="error"
POWERKIT_PLUGIN_DISK_CRITICAL_ACCENT_COLOR_ICON="error"

# =============================================================================
# PLUGIN: network
# =============================================================================

POWERKIT_PLUGIN_NETWORK_ICON="󰫳"
POWERKIT_PLUGIN_NETWORK_ACCENT_COLOR="success"
POWERKIT_PLUGIN_NETWORK_ACCENT_COLOR_ICON="success"
POWERKIT_PLUGIN_NETWORK_INTERFACE=""
POWERKIT_PLUGIN_NETWORK_CACHE_TTL="4"
POWERKIT_PLUGIN_NETWORK_THRESHOLD="51200"

# =============================================================================
# PLUGIN: loadavg
# =============================================================================

POWERKIT_PLUGIN_LOADAVG_ICON="󰪪"
POWERKIT_PLUGIN_LOADAVG_ACCENT_COLOR="info"
POWERKIT_PLUGIN_LOADAVG_ACCENT_COLOR_ICON="info"
POWERKIT_PLUGIN_LOADAVG_FORMAT="1"
POWERKIT_PLUGIN_LOADAVG_CACHE_TTL="8"

# Threshold settings for dynamic colors (multipliers of CPU cores)
# Default: warning at 2x cores, critical at 4x cores
POWERKIT_PLUGIN_LOADAVG_WARNING_THRESHOLD_MULTIPLIER="2"
POWERKIT_PLUGIN_LOADAVG_CRITICAL_THRESHOLD_MULTIPLIER="4"
POWERKIT_PLUGIN_LOADAVG_WARNING_ACCENT_COLOR="warning"
POWERKIT_PLUGIN_LOADAVG_WARNING_ACCENT_COLOR_ICON="warning"
POWERKIT_PLUGIN_LOADAVG_CRITICAL_ACCENT_COLOR="error"
POWERKIT_PLUGIN_LOADAVG_CRITICAL_ACCENT_COLOR_ICON="error"

# =============================================================================
# PLUGIN: uptime
# =============================================================================

POWERKIT_PLUGIN_UPTIME_ICON="󰤟"
POWERKIT_PLUGIN_UPTIME_ACCENT_COLOR="secondary"
POWERKIT_PLUGIN_UPTIME_ACCENT_COLOR_ICON="secondary"
POWERKIT_PLUGIN_UPTIME_CACHE_TTL="300"

# =============================================================================
# PLUGIN: git
# =============================================================================

POWERKIT_PLUGIN_GIT_ICON=""
POWERKIT_PLUGIN_GIT_ACCENT_COLOR="success"
POWERKIT_PLUGIN_GIT_ACCENT_COLOR_ICON="success"
POWERKIT_PLUGIN_GIT_CACHE_TTL="5"

# Git colors when there are modifications in the active branch  
POWERKIT_PLUGIN_GIT_MODIFIED_ACCENT_COLOR="warning"
POWERKIT_PLUGIN_GIT_MODIFIED_ACCENT_COLOR_ICON="warning"

# =============================================================================
# PLUGIN: kubernetes
# =============================================================================

POWERKIT_PLUGIN_KUBERNETES_ICON="󱃾"
POWERKIT_PLUGIN_KUBERNETES_ACCENT_COLOR="info"
POWERKIT_PLUGIN_KUBERNETES_ACCENT_COLOR_ICON="info"
POWERKIT_PLUGIN_KUBERNETES_DISPLAY_MODE="connected"
POWERKIT_PLUGIN_KUBERNETES_SHOW_NAMESPACE="false"
POWERKIT_PLUGIN_KUBERNETES_CONNECTIVITY_TIMEOUT="2"
POWERKIT_PLUGIN_KUBERNETES_CONNECTIVITY_CACHE_TTL="120"
POWERKIT_PLUGIN_KUBERNETES_CACHE_TTL="45"

# Keybinding for context selector popup (requires kubectl-ctx from krew)
# Set to empty string to disable the keybinding
POWERKIT_PLUGIN_KUBERNETES_CONTEXT_SELECTOR_KEY="K"
POWERKIT_PLUGIN_KUBERNETES_CONTEXT_SELECTOR_WIDTH="50%"
POWERKIT_PLUGIN_KUBERNETES_CONTEXT_SELECTOR_HEIGHT="50%"

# Keybinding for namespace selector popup (requires kubectl-ns from krew)
# Set to empty string to disable the keybinding
POWERKIT_PLUGIN_KUBERNETES_NAMESPACE_SELECTOR_KEY="N"
POWERKIT_PLUGIN_KUBERNETES_NAMESPACE_SELECTOR_WIDTH="50%"
POWERKIT_PLUGIN_KUBERNETES_NAMESPACE_SELECTOR_HEIGHT="50%"

# =============================================================================
# PLUGIN: hostname
# =============================================================================

POWERKIT_PLUGIN_HOSTNAME_ICON="💻"
POWERKIT_PLUGIN_HOSTNAME_ACCENT_COLOR="secondary"
POWERKIT_PLUGIN_HOSTNAME_ACCENT_COLOR_ICON="secondary"
POWERKIT_PLUGIN_HOSTNAME_FORMAT="short"

# =============================================================================
# PLUGIN: packages (unified: homebrew, yay, apt, dnf, pacman)
# =============================================================================

POWERKIT_PLUGIN_PACKAGES_ICON="󰪰"
POWERKIT_PLUGIN_PACKAGES_ACCENT_COLOR="primary"
POWERKIT_PLUGIN_PACKAGES_ACCENT_COLOR_ICON="primary"
POWERKIT_PLUGIN_PACKAGES_BACKEND="auto"
POWERKIT_PLUGIN_PACKAGES_BREW_OPTIONS="--greedy"
POWERKIT_PLUGIN_PACKAGES_CACHE_TTL="3600"

# =============================================================================
# PLUGIN: nowplaying (unified: spotify, spt, playerctl, osascript)
# =============================================================================

POWERKIT_PLUGIN_NOWPLAYING_ICON="󰝚"
POWERKIT_PLUGIN_NOWPLAYING_ACCENT_COLOR="accent"
POWERKIT_PLUGIN_NOWPLAYING_ACCENT_COLOR_ICON="accent"
POWERKIT_PLUGIN_NOWPLAYING_FORMAT="%artist% - %track%"
POWERKIT_PLUGIN_NOWPLAYING_MAX_LENGTH="40"
POWERKIT_PLUGIN_NOWPLAYING_NOT_PLAYING=""
POWERKIT_PLUGIN_NOWPLAYING_BACKEND="auto"
POWERKIT_PLUGIN_NOWPLAYING_IGNORE_PLAYERS="IGNORE"
POWERKIT_PLUGIN_NOWPLAYING_CACHE_TTL="5"

# =============================================================================
# PLUGIN: volume
# =============================================================================

POWERKIT_PLUGIN_VOLUME_ICON="󰥾"
POWERKIT_PLUGIN_VOLUME_ICON_MUTED="󰦁"
POWERKIT_PLUGIN_VOLUME_ICON_LOW="󰥿"
POWERKIT_PLUGIN_VOLUME_ICON_MEDIUM="󰦀"
POWERKIT_PLUGIN_VOLUME_ACCENT_COLOR="info"
POWERKIT_PLUGIN_VOLUME_ACCENT_COLOR_ICON="info"
POWERKIT_PLUGIN_VOLUME_MUTED_ACCENT_COLOR="error"
POWERKIT_PLUGIN_VOLUME_MUTED_ACCENT_COLOR_ICON="error"
POWERKIT_PLUGIN_VOLUME_LOW_THRESHOLD="30"
POWERKIT_PLUGIN_VOLUME_MEDIUM_THRESHOLD="70"
POWERKIT_PLUGIN_VOLUME_CACHE_TTL="3"

# =============================================================================
# PLUGIN: wifi
# =============================================================================

POWERKIT_PLUGIN_WIFI_ICON="󰤨"
POWERKIT_PLUGIN_WIFI_ICON_DISCONNECTED="󰤭"
POWERKIT_PLUGIN_WIFI_ACCENT_COLOR="success"
POWERKIT_PLUGIN_WIFI_ACCENT_COLOR_ICON="success"
POWERKIT_PLUGIN_WIFI_SHOW_SSID="true"
POWERKIT_PLUGIN_WIFI_SHOW_IP="false"
POWERKIT_PLUGIN_WIFI_SHOW_SIGNAL="false"
POWERKIT_PLUGIN_WIFI_CACHE_TTL="15"

# =============================================================================
# PLUGIN: bluetooth
# =============================================================================

PLUGIN_BLUETOOTH_ICON="󰂯"
PLUGIN_BLUETOOTH_ICON_OFF="󰂲"
PLUGIN_BLUETOOTH_ICON_CONNECTED="󰂱"
POWERKIT_PLUGIN_BLUETOOTH_ACCENT_COLOR="info"
POWERKIT_PLUGIN_BLUETOOTH_ACCENT_COLOR_ICON="info"
POWERKIT_PLUGIN_BLUETOOTH_SHOW_DEVICE="true"
POWERKIT_PLUGIN_BLUETOOTH_SHOW_BATTERY="true"
POWERKIT_PLUGIN_BLUETOOTH_FORMAT="all"
POWERKIT_PLUGIN_BLUETOOTH_MAX_LENGTH="25"
POWERKIT_PLUGIN_BLUETOOTH_CACHE_TTL="20"

# =============================================================================
# PLUGIN: vpn
# =============================================================================

POWERKIT_PLUGIN_VPN_ICON="󰨾"
POWERKIT_PLUGIN_VPN_ICON_DISCONNECTED="󰫞"
POWERKIT_PLUGIN_VPN_ACCENT_COLOR="success"
POWERKIT_PLUGIN_VPN_ACCENT_COLOR_ICON="success"
POWERKIT_PLUGIN_VPN_SHOW_NAME="true"
POWERKIT_PLUGIN_VPN_SHOW_IP="false"
POWERKIT_PLUGIN_VPN_SHOW_WHEN_DISCONNECTED="false"
POWERKIT_PLUGIN_VPN_MAX_LENGTH="20"
POWERKIT_PLUGIN_VPN_CACHE_TTL="15"

# =============================================================================
# PLUGIN: temperature
# =============================================================================

POWERKIT_PLUGIN_TEMPERATURE_ICON="󰤏"
POWERKIT_PLUGIN_TEMPERATURE_ICON_HOT="󰸁"
POWERKIT_PLUGIN_TEMPERATURE_ACCENT_COLOR="info"
POWERKIT_PLUGIN_TEMPERATURE_ACCENT_COLOR_ICON="info"
POWERKIT_PLUGIN_TEMPERATURE_UNIT="C"
# Source options: cpu, cpu-pkg, cpu-acpi, nvme, wifi, acpi, dell, auto
POWERKIT_PLUGIN_TEMPERATURE_SOURCE="cpu"
POWERKIT_PLUGIN_TEMPERATURE_CACHE_TTL="10"

# Threshold settings for dynamic colors
POWERKIT_PLUGIN_TEMPERATURE_WARNING_THRESHOLD="60"
POWERKIT_PLUGIN_TEMPERATURE_CRITICAL_THRESHOLD="80"
POWERKIT_PLUGIN_TEMPERATURE_WARNING_ACCENT_COLOR="warning"
POWERKIT_PLUGIN_TEMPERATURE_WARNING_ACCENT_COLOR_ICON="warning"
POWERKIT_PLUGIN_TEMPERATURE_CRITICAL_ACCENT_COLOR="error"
POWERKIT_PLUGIN_TEMPERATURE_CRITICAL_ACCENT_COLOR_ICON="error"

# =============================================================================
# PLUGIN: external_ip
# =============================================================================

POWERKIT_PLUGIN_EXTERNAL_IP_ICON="󰩟"
POWERKIT_PLUGIN_EXTERNAL_IP_ACCENT_COLOR="secondary"
POWERKIT_PLUGIN_EXTERNAL_IP_ACCENT_COLOR_ICON="secondary"
POWERKIT_PLUGIN_EXTERNAL_IP_CACHE_TTL="300"

# =============================================================================
# PLUGIN: brightness
# =============================================================================

POWERKIT_PLUGIN_BRIGHTNESS_ICON="󰤞"
POWERKIT_PLUGIN_BRIGHTNESS_ICON_LOW="󰤚"
POWERKIT_PLUGIN_BRIGHTNESS_ICON_MEDIUM="󰤝"
POWERKIT_PLUGIN_BRIGHTNESS_ICON_HIGH="󰤞"
POWERKIT_PLUGIN_BRIGHTNESS_ACCENT_COLOR="warning"
POWERKIT_PLUGIN_BRIGHTNESS_ACCENT_COLOR_ICON="warning"
POWERKIT_PLUGIN_BRIGHTNESS_CACHE_TTL="4"

# =============================================================================
# PLUGIN: cloud
# =============================================================================

POWERKIT_PLUGIN_CLOUD_ICON=$'\udb80\udd5f'
POWERKIT_PLUGIN_CLOUD_ICON_AWS=$'\ue7ad'
POWERKIT_PLUGIN_CLOUD_ICON_GCP=$'\ue7f1'
POWERKIT_PLUGIN_CLOUD_ICON_AZURE=$'\ue754'
POWERKIT_PLUGIN_CLOUD_ICON_MULTI="☁️"
POWERKIT_PLUGIN_CLOUD_ACCENT_COLOR="info"
POWERKIT_PLUGIN_CLOUD_ACCENT_COLOR_ICON="info"
POWERKIT_PLUGIN_CLOUD_PROVIDERS="all"
POWERKIT_PLUGIN_CLOUD_FORMAT="short"
POWERKIT_PLUGIN_CLOUD_SHOW_ACCOUNT="false"
POWERKIT_PLUGIN_CLOUD_SHOW_REGION="true"
POWERKIT_PLUGIN_CLOUD_MAX_LENGTH="40"
POWERKIT_PLUGIN_CLOUD_SEPARATOR=" | "
POWERKIT_PLUGIN_CLOUD_WARN_ON_PROD="true"
POWERKIT_PLUGIN_CLOUD_PROD_KEYWORDS="prod,production,prd"
POWERKIT_PLUGIN_CLOUD_PROD_ACCENT_COLOR="error"
POWERKIT_PLUGIN_CLOUD_CACHE_TTL="60"

# =============================================================================
# SMARTKEY PLUGIN DEFAULTS
# =============================================================================

POWERKIT_PLUGIN_SMARTKEY_ICON=$'\uf084'
POWERKIT_PLUGIN_SMARTKEY_WAITING_ICON=$'\ue23f'
POWERKIT_PLUGIN_SMARTKEY_ACCENT_COLOR="accent"
POWERKIT_PLUGIN_SMARTKEY_ACCENT_COLOR_ICON="accent"
POWERKIT_PLUGIN_SMARTKEY_WAITING_ACCENT_COLOR="error"
POWERKIT_PLUGIN_SMARTKEY_WAITING_ACCENT_COLOR_ICON="error"
POWERKIT_PLUGIN_SMARTKEY_CACHE_TTL="1"
POWERKIT_PLUGIN_SMARTKEY_SHOW_WHEN_INACTIVE="false"

# =============================================================================
# CACHE SYSTEM DEFAULTS
# =============================================================================

# Cache clear keybinding  
POWERKIT_PLUGIN_CACHE_CLEAR_KEY="Q"

# =============================================================================
# POWERKIT THRESHOLD SYSTEM DEFAULTS (applies to all plugins using thresholds)  
# =============================================================================

# 3-level threshold defaults using semantic colors
POWERKIT_THRESHOLD_CRITICAL_VALUE="10"
POWERKIT_THRESHOLD_WARNING_VALUE="30"
POWERKIT_THRESHOLD_CRITICAL_COLOR="error"
POWERKIT_THRESHOLD_CRITICAL_COLOR_ICON="error"
POWERKIT_THRESHOLD_WARNING_COLOR="warning"
POWERKIT_THRESHOLD_WARNING_COLOR_ICON="warning"
POWERKIT_THRESHOLD_NORMAL_COLOR="success"
POWERKIT_THRESHOLD_NORMAL_COLOR_ICON="success"
