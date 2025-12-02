#!/usr/bin/env bash
# =============================================================================
# Theme Defaults Configuration
# =============================================================================
# This file contains all default values for the Tokyo Night tmux theme.
# Modify values here to change defaults across the entire theme.
# Users can still override any option in their tmux.conf.
#
# Usage: These defaults are applied when the theme loads. User configurations
#        in tmux.conf take precedence over these defaults.
#
# To use in a plugin:
#   1. Source this file: . "$ROOT_DIR/../defaults.sh"
#   2. Use variables like: $(get_tmux_option "@theme_plugin_X_icon" "$PLUGIN_X_ICON")
# =============================================================================

# shellcheck disable=SC2034
# All variables in this file are intentionally exported for use by other scripts
# that source this file. ShellCheck cannot track cross-file variable usage.

# Prevent multiple sourcing
[[ -n "${_DEFAULTS_LOADED:-}" ]] && return 0
_DEFAULTS_LOADED=1

# =============================================================================
# Helper: Get default for a plugin option
# Usage: get_plugin_default "battery" "icon" -> returns $PLUGIN_BATTERY_ICON
# =============================================================================
get_plugin_default() {
    local plugin_name="${1^^}"  # uppercase
    local option_name="${2^^}"  # uppercase
    plugin_name="${plugin_name//-/_}"  # replace - with _
    option_name="${option_name//-/_}"  # replace - with _
    local var_name="PLUGIN_${plugin_name}_${option_name}"
    printf '%s' "${!var_name:-}"
}

# =============================================================================
# THEME CORE OPTIONS
# =============================================================================

# Theme variation: night, storm, moon, day
THEME_DEFAULT_VARIATION="night"

# Disable all plugins: 0 = enabled, 1 = disabled
THEME_DEFAULT_DISABLE_PLUGINS=0

# Status bar layout: single
THEME_DEFAULT_BAR_LAYOUT="single"

# Transparent status bar: true, false
THEME_DEFAULT_TRANSPARENT="false"

# Default plugins to enable (comma-separated)
THEME_DEFAULT_PLUGINS="datetime,hostname,git,battery,cpu,memory"

# Status bar lengths
THEME_DEFAULT_STATUS_LEFT_LENGTH="100"
THEME_DEFAULT_STATUS_RIGHT_LENGTH="1000"

# =============================================================================
# SEPARATORS
# =============================================================================

# Powerline separators (Unicode characters)
THEME_DEFAULT_LEFT_SEPARATOR=$'\ue0b0'
THEME_DEFAULT_RIGHT_SEPARATOR=$'\ue0b2'

# Inverse separators for transparent mode
THEME_DEFAULT_LEFT_SEPARATOR_INVERSE=$'\ue0d4'
THEME_DEFAULT_RIGHT_SEPARATOR_INVERSE=$'\ue0d6'


# =============================================================================
# SESSION & WINDOW ICONS
# =============================================================================

# Auto-detect OS icon if not explicitly set
# Users can override by setting @theme_session_icon manually
THEME_DEFAULT_SESSION_ICON="auto"
THEME_DEFAULT_ACTIVE_WINDOW_ICON=""
THEME_DEFAULT_INACTIVE_WINDOW_ICON=""
THEME_DEFAULT_ZOOMED_WINDOW_ICON=""
THEME_DEFAULT_PANE_SYNCHRONIZED_ICON="✵"

# =============================================================================
# WINDOW TITLES
# =============================================================================

THEME_DEFAULT_ACTIVE_WINDOW_TITLE="#W "
THEME_DEFAULT_INACTIVE_WINDOW_TITLE="#W "

# =============================================================================
# WINDOW STYLES
# =============================================================================

# Style for windows with activity: italics, bold, none, etc.
THEME_DEFAULT_WINDOW_WITH_ACTIVITY_STYLE="italics"

# Active window colors (can use palette color names)
THEME_DEFAULT_ACTIVE_WINDOW_NUMBER_BG="magenta"
THEME_DEFAULT_ACTIVE_WINDOW_CONTENT_BG="purple"

# Style for bell status
THEME_DEFAULT_STATUS_BELL_STYLE="bold"

# =============================================================================
# THEME HELPER KEYBINDINGS
# =============================================================================

# Key to open theme options reference popup (prefix + key)
# Set to empty string to disable
THEME_DEFAULT_HELPER_KEY="?"
THEME_DEFAULT_HELPER_WIDTH="80%"
THEME_DEFAULT_HELPER_HEIGHT="80%"

# Key to open keybindings viewer popup (prefix + key)
# Set to empty string to disable
THEME_DEFAULT_KEYBINDINGS_KEY="B"
THEME_DEFAULT_KEYBINDINGS_WIDTH="80%"
THEME_DEFAULT_KEYBINDINGS_HEIGHT="80%"

# =============================================================================
# PLUGIN: audio  
# =============================================================================
# Audio device plugin - shows current input/output devices and provides keybindings
THEME_DEFAULT_PLUGIN_AUDIODEVICES_SHOW="both"                   # off|input|output|both

THEME_DEFAULT_PLUGIN_AUDIODEVICES_ICON=$'\uf0ec'  
THEME_DEFAULT_PLUGIN_AUDIODEVICES_INPUT_ICON=$'\uec1c'               # Input device icon
THEME_DEFAULT_PLUGIN_AUDIODEVICES_OUTPUT_ICON=$'\uf027'              # Output device icon  
THEME_DEFAULT_PLUGIN_AUDIODEVICES_SEPARATOR=" | "               # Separator between devices
THEME_DEFAULT_PLUGIN_AUDIODEVICES_CACHE_TTL="8"                 # Cache time in seconds
THEME_DEFAULT_PLUGIN_AUDIODEVICES_MAX_LENGTH="15"               # Max device name length
THEME_DEFAULT_PLUGIN_AUDIODEVICES_INPUT_KEY="I"                 # Input selection key (prefix + key)
THEME_DEFAULT_PLUGIN_AUDIODEVICES_OUTPUT_KEY="O"                # Output selection key (prefix + key)

PLUGIN_AUDIODEVICES_ACCENT_COLOR="blue7"
PLUGIN_AUDIODEVICES_ACCENT_COLOR_ICON="blue0"

# =============================================================================
# PLUGIN: camera
# =============================================================================
# Camera status plugin - shows when camera is active/inactive
THEME_DEFAULT_PLUGIN_CAMERA_SHOW="on"                          # on|off
THEME_DEFAULT_PLUGIN_CAMERA_ICON="📷"                          # Camera icon when inactive
THEME_DEFAULT_PLUGIN_CAMERA_ICON_ACTIVE="🔴"                   # Camera icon when active  
THEME_DEFAULT_PLUGIN_CAMERA_CACHE_TTL="5"                      # Cache time in seconds
THEME_DEFAULT_PLUGIN_CAMERA_SHOW_WHEN_INACTIVE="false"         # Show when camera is off

PLUGIN_CAMERA_ACCENT_COLOR="blue7"
PLUGIN_CAMERA_ACCENT_COLOR_ICON="blue0"

# =============================================================================
# PLUGIN: datetime
# =============================================================================

PLUGIN_DATETIME_ICON="󰥔"
PLUGIN_DATETIME_ACCENT_COLOR="blue7"
PLUGIN_DATETIME_ACCENT_COLOR_ICON="blue0"

# Format: predefined (time, time-seconds, time-12h, date, date-full, date-iso,
#         datetime, weekday, full, iso) or custom strftime format
PLUGIN_DATETIME_FORMAT="datetime"

# Secondary timezone (e.g., "America/New_York", "Europe/London", "Asia/Tokyo")
# Leave empty to disable
PLUGIN_DATETIME_TIMEZONE=""

# Show week number (true/false) - displays "W48" before the date
PLUGIN_DATETIME_SHOW_WEEK="false"

# Separator between elements (week, date/time, timezone)
PLUGIN_DATETIME_SEPARATOR=" "

# =============================================================================
# PLUGIN: weather
# =============================================================================

PLUGIN_WEATHER_ICON="󰖐"
PLUGIN_WEATHER_ACCENT_COLOR="blue7"
PLUGIN_WEATHER_ACCENT_COLOR_ICON="blue0"
PLUGIN_WEATHER_LOCATION=""
PLUGIN_WEATHER_UNIT=""
# Format: "compact", "full", "minimal", "detailed", or custom wttr.in format
PLUGIN_WEATHER_FORMAT="compact"
PLUGIN_WEATHER_CACHE_TTL="900"

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

# Battery charging settings
PLUGIN_BATTERY_ICON_CHARGING="󰂄"

# =============================================================================
# PLUGIN: cpu
# =============================================================================

PLUGIN_CPU_ICON=""
PLUGIN_CPU_ACCENT_COLOR="blue7"
PLUGIN_CPU_ACCENT_COLOR_ICON="blue0"
PLUGIN_CPU_CACHE_TTL="3"

# Threshold settings for dynamic colors
PLUGIN_CPU_WARNING_THRESHOLD="70"
PLUGIN_CPU_CRITICAL_THRESHOLD="90"
PLUGIN_CPU_WARNING_ACCENT_COLOR="yellow"
PLUGIN_CPU_WARNING_ACCENT_COLOR_ICON="orange"
PLUGIN_CPU_CRITICAL_ACCENT_COLOR="red"
PLUGIN_CPU_CRITICAL_ACCENT_COLOR_ICON="red1"

# =============================================================================
# PLUGIN: memory
# =============================================================================

PLUGIN_MEMORY_ICON=""
PLUGIN_MEMORY_ACCENT_COLOR="blue7"
PLUGIN_MEMORY_ACCENT_COLOR_ICON="blue0"
PLUGIN_MEMORY_FORMAT="percent"
PLUGIN_MEMORY_CACHE_TTL="5"

# Threshold settings for dynamic colors
PLUGIN_MEMORY_WARNING_THRESHOLD="70"
PLUGIN_MEMORY_CRITICAL_THRESHOLD="90"
PLUGIN_MEMORY_WARNING_ACCENT_COLOR="yellow"
PLUGIN_MEMORY_WARNING_ACCENT_COLOR_ICON="orange"
PLUGIN_MEMORY_CRITICAL_ACCENT_COLOR="red"
PLUGIN_MEMORY_CRITICAL_ACCENT_COLOR_ICON="red1"

# =============================================================================
# PLUGIN: disk
# =============================================================================

PLUGIN_DISK_ICON="󰋊"
PLUGIN_DISK_ACCENT_COLOR="blue7"
PLUGIN_DISK_ACCENT_COLOR_ICON="blue0"
PLUGIN_DISK_MOUNT="/"
PLUGIN_DISK_FORMAT="percent"
PLUGIN_DISK_CACHE_TTL="120"

# Threshold settings for dynamic colors
PLUGIN_DISK_WARNING_THRESHOLD="70"
PLUGIN_DISK_CRITICAL_THRESHOLD="90"
PLUGIN_DISK_WARNING_ACCENT_COLOR="yellow"
PLUGIN_DISK_WARNING_ACCENT_COLOR_ICON="orange"
PLUGIN_DISK_CRITICAL_ACCENT_COLOR="red"
PLUGIN_DISK_CRITICAL_ACCENT_COLOR_ICON="red1"

# =============================================================================
# PLUGIN: network
# =============================================================================

PLUGIN_NETWORK_ICON="󰛳"
PLUGIN_NETWORK_ACCENT_COLOR="blue7"
PLUGIN_NETWORK_ACCENT_COLOR_ICON="blue0"
PLUGIN_NETWORK_INTERFACE=""
PLUGIN_NETWORK_CACHE_TTL="4"
PLUGIN_NETWORK_THRESHOLD="51200"

# =============================================================================
# PLUGIN: loadavg
# =============================================================================

PLUGIN_LOADAVG_ICON="󰊚"
PLUGIN_LOADAVG_ACCENT_COLOR="blue7"
PLUGIN_LOADAVG_ACCENT_COLOR_ICON="blue0"
PLUGIN_LOADAVG_FORMAT="1"
PLUGIN_LOADAVG_CACHE_TTL="8"

# Threshold settings for dynamic colors (multipliers of CPU cores)
# Default: warning at 2x cores, critical at 4x cores
PLUGIN_LOADAVG_WARNING_THRESHOLD_MULTIPLIER="2"
PLUGIN_LOADAVG_CRITICAL_THRESHOLD_MULTIPLIER="4"
PLUGIN_LOADAVG_WARNING_ACCENT_COLOR="yellow"
PLUGIN_LOADAVG_WARNING_ACCENT_COLOR_ICON="orange"
PLUGIN_LOADAVG_CRITICAL_ACCENT_COLOR="red"
PLUGIN_LOADAVG_CRITICAL_ACCENT_COLOR_ICON="red1"

# =============================================================================
# PLUGIN: uptime
# =============================================================================

PLUGIN_UPTIME_ICON="󰔟"
PLUGIN_UPTIME_ACCENT_COLOR="blue7"
PLUGIN_UPTIME_ACCENT_COLOR_ICON="blue0"
PLUGIN_UPTIME_CACHE_TTL="300"

# =============================================================================
# PLUGIN: git
# =============================================================================

PLUGIN_GIT_ICON=""
PLUGIN_GIT_ACCENT_COLOR="blue7"
PLUGIN_GIT_ACCENT_COLOR_ICON="blue0"
PLUGIN_GIT_CACHE_TTL="5"

# =============================================================================
# PLUGIN: kubernetes
# =============================================================================

PLUGIN_KUBERNETES_ICON="󱃾"
PLUGIN_KUBERNETES_ACCENT_COLOR="blue7"
PLUGIN_KUBERNETES_ACCENT_COLOR_ICON="blue0"
PLUGIN_KUBERNETES_DISPLAY_MODE="connected"
PLUGIN_KUBERNETES_SHOW_NAMESPACE="false"
PLUGIN_KUBERNETES_CONNECTIVITY_TIMEOUT="2"
PLUGIN_KUBERNETES_CONNECTIVITY_CACHE_TTL="120"
PLUGIN_KUBERNETES_CACHE_TTL="45"

# Keybinding for context selector popup (requires kubectl-ctx from krew)
# Set to empty string to disable the keybinding
PLUGIN_KUBERNETES_CONTEXT_SELECTOR_KEY="K"
PLUGIN_KUBERNETES_CONTEXT_SELECTOR_WIDTH="50%"
PLUGIN_KUBERNETES_CONTEXT_SELECTOR_HEIGHT="50%"

# Keybinding for namespace selector popup (requires kubectl-ns from krew)
# Set to empty string to disable the keybinding
PLUGIN_KUBERNETES_NAMESPACE_SELECTOR_KEY="N"
PLUGIN_KUBERNETES_NAMESPACE_SELECTOR_WIDTH="50%"
PLUGIN_KUBERNETES_NAMESPACE_SELECTOR_HEIGHT="50%"

# =============================================================================
# PLUGIN: hostname
# =============================================================================

PLUGIN_HOSTNAME_ICON="💻"
PLUGIN_HOSTNAME_ACCENT_COLOR="blue7"
PLUGIN_HOSTNAME_ACCENT_COLOR_ICON="blue0"
PLUGIN_HOSTNAME_FORMAT="short"

# =============================================================================
# PLUGIN: packages (unified: homebrew, yay, apt, dnf, pacman)
# =============================================================================

PLUGIN_PACKAGES_ICON="󰚰"
PLUGIN_PACKAGES_ACCENT_COLOR="blue7"
PLUGIN_PACKAGES_ACCENT_COLOR_ICON="blue0"
PLUGIN_PACKAGES_BACKEND="auto"
PLUGIN_PACKAGES_BREW_OPTIONS="--greedy"
PLUGIN_PACKAGES_CACHE_TTL="3600"

# =============================================================================
# PLUGIN: nowplaying (unified: spotify, spt, playerctl, osascript)
# =============================================================================

PLUGIN_NOWPLAYING_ICON="󰝚"
PLUGIN_NOWPLAYING_ACCENT_COLOR="blue7"
PLUGIN_NOWPLAYING_ACCENT_COLOR_ICON="blue0"
PLUGIN_NOWPLAYING_FORMAT="%artist% - %track%"
PLUGIN_NOWPLAYING_MAX_LENGTH="40"
PLUGIN_NOWPLAYING_NOT_PLAYING=""
PLUGIN_NOWPLAYING_BACKEND="auto"
PLUGIN_NOWPLAYING_IGNORE_PLAYERS="IGNORE"
PLUGIN_NOWPLAYING_CACHE_TTL="5"

# =============================================================================
# PLUGIN: volume
# =============================================================================

PLUGIN_VOLUME_ICON="󰕾"
PLUGIN_VOLUME_ICON_MUTED="󰖁"
PLUGIN_VOLUME_ICON_LOW="󰕿"
PLUGIN_VOLUME_ICON_MEDIUM="󰖀"
PLUGIN_VOLUME_ACCENT_COLOR="blue7"
PLUGIN_VOLUME_ACCENT_COLOR_ICON="blue0"
PLUGIN_VOLUME_LOW_THRESHOLD="30"
PLUGIN_VOLUME_MEDIUM_THRESHOLD="70"
PLUGIN_VOLUME_CACHE_TTL="3"

# =============================================================================
# PLUGIN: wifi
# =============================================================================

PLUGIN_WIFI_ICON="󰤨"
PLUGIN_WIFI_ICON_DISCONNECTED="󰤭"
PLUGIN_WIFI_ACCENT_COLOR="blue7"
PLUGIN_WIFI_ACCENT_COLOR_ICON="blue0"
PLUGIN_WIFI_SHOW_SSID="true"
PLUGIN_WIFI_SHOW_IP="false"
PLUGIN_WIFI_SHOW_SIGNAL="false"
PLUGIN_WIFI_CACHE_TTL="15"

# =============================================================================
# PLUGIN: bluetooth
# =============================================================================

PLUGIN_BLUETOOTH_ICON="󰂯"
PLUGIN_BLUETOOTH_ICON_OFF="󰂲"
PLUGIN_BLUETOOTH_ICON_CONNECTED="󰂱"
PLUGIN_BLUETOOTH_ACCENT_COLOR="blue7"
PLUGIN_BLUETOOTH_ACCENT_COLOR_ICON="blue0"
PLUGIN_BLUETOOTH_SHOW_DEVICE="true"
PLUGIN_BLUETOOTH_SHOW_BATTERY="true"
PLUGIN_BLUETOOTH_FORMAT="all"
PLUGIN_BLUETOOTH_MAX_LENGTH="25"
PLUGIN_BLUETOOTH_CACHE_TTL="20"

# =============================================================================
# PLUGIN: vpn
# =============================================================================

PLUGIN_VPN_ICON="󰌾"
PLUGIN_VPN_ICON_DISCONNECTED="󰦞"
PLUGIN_VPN_ACCENT_COLOR="blue7"
PLUGIN_VPN_ACCENT_COLOR_ICON="blue0"
PLUGIN_VPN_SHOW_NAME="true"
PLUGIN_VPN_SHOW_IP="false"
PLUGIN_VPN_SHOW_WHEN_DISCONNECTED="false"
PLUGIN_VPN_MAX_LENGTH="20"
PLUGIN_VPN_CACHE_TTL="15"

# =============================================================================
# PLUGIN: temperature
# =============================================================================

PLUGIN_TEMPERATURE_ICON="󰔏"
PLUGIN_TEMPERATURE_ICON_HOT="󰸁"
PLUGIN_TEMPERATURE_ACCENT_COLOR="blue7"
PLUGIN_TEMPERATURE_ACCENT_COLOR_ICON="blue0"
PLUGIN_TEMPERATURE_UNIT="C"
# Source options: cpu, cpu-pkg, cpu-acpi, nvme, wifi, acpi, dell, auto
PLUGIN_TEMPERATURE_SOURCE="cpu"
PLUGIN_TEMPERATURE_CACHE_TTL="10"

# Threshold settings for dynamic colors
PLUGIN_TEMPERATURE_WARNING_THRESHOLD="60"
PLUGIN_TEMPERATURE_CRITICAL_THRESHOLD="80"
PLUGIN_TEMPERATURE_WARNING_ACCENT_COLOR="yellow"
PLUGIN_TEMPERATURE_WARNING_ACCENT_COLOR_ICON="orange"
PLUGIN_TEMPERATURE_CRITICAL_ACCENT_COLOR="red"
PLUGIN_TEMPERATURE_CRITICAL_ACCENT_COLOR_ICON="red1"

# =============================================================================
# PLUGIN: external_ip
# =============================================================================

PLUGIN_EXTERNAL_IP_ICON="󰩟"
PLUGIN_EXTERNAL_IP_ACCENT_COLOR="blue7"
PLUGIN_EXTERNAL_IP_ACCENT_COLOR_ICON="blue0"
PLUGIN_EXTERNAL_IP_CACHE_TTL="300"

# =============================================================================
# PLUGIN: brightness
# =============================================================================

PLUGIN_BRIGHTNESS_ICON="󰃞"
PLUGIN_BRIGHTNESS_ICON_LOW="󰃚"
PLUGIN_BRIGHTNESS_ICON_MEDIUM="󰃝"
PLUGIN_BRIGHTNESS_ICON_HIGH="󰃞"
PLUGIN_BRIGHTNESS_ACCENT_COLOR="blue7"
PLUGIN_BRIGHTNESS_ACCENT_COLOR_ICON="blue0"
PLUGIN_BRIGHTNESS_CACHE_TTL="4"

# =============================================================================
# PLUGIN: cloud
# =============================================================================

PLUGIN_CLOUD_ICON=$'\udb80\udd5f'
PLUGIN_CLOUD_ICON_AWS=$'\ue7ad'
PLUGIN_CLOUD_ICON_GCP=$'\ue7f1'
PLUGIN_CLOUD_ICON_AZURE=$'\ue754'
PLUGIN_CLOUD_ICON_MULTI="☁️"
PLUGIN_CLOUD_ACCENT_COLOR="blue7"
PLUGIN_CLOUD_ACCENT_COLOR_ICON="blue0"
PLUGIN_CLOUD_PROVIDERS="all"
PLUGIN_CLOUD_FORMAT="short"
PLUGIN_CLOUD_SHOW_ACCOUNT="false"
PLUGIN_CLOUD_SHOW_REGION="true"
PLUGIN_CLOUD_MAX_LENGTH="40"
PLUGIN_CLOUD_SEPARATOR=" | "
PLUGIN_CLOUD_WARN_ON_PROD="true"
PLUGIN_CLOUD_PROD_KEYWORDS="prod,production,prd"
PLUGIN_CLOUD_PROD_ACCENT_COLOR="red"
PLUGIN_CLOUD_CACHE_TTL="60"

# =============================================================================
# THRESHOLD SYSTEM DEFAULTS (applies to all plugins using thresholds)
# =============================================================================

# 3-level threshold defaults
THRESHOLD_CRITICAL_VALUE="10"
THRESHOLD_WARNING_VALUE="30"
THRESHOLD_CRITICAL_COLOR="red"
THRESHOLD_CRITICAL_COLOR_ICON="red1"
THRESHOLD_WARNING_COLOR="yellow"
THRESHOLD_WARNING_COLOR_ICON="orange"
THRESHOLD_NORMAL_COLOR="green"
THRESHOLD_NORMAL_COLOR_ICON="green1"
