#!/usr/bin/env bash
# =============================================================================
# Plugin: disk
# Description: Display disk usage for a specified mount point
# Dependencies: df
# =============================================================================

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck source=src/utils.sh
. "$ROOT_DIR/../utils.sh"
# shellcheck source=src/cache.sh
. "$ROOT_DIR/../cache.sh"

# =============================================================================
# Plugin Configuration
# =============================================================================

# shellcheck disable=SC2034
plugin_disk_icon=$(get_tmux_option "@theme_plugin_disk_icon" "󰋊 ")
# shellcheck disable=SC2034
plugin_disk_accent_color=$(get_tmux_option "@theme_plugin_disk_accent_color" "blue7")
# shellcheck disable=SC2034
plugin_disk_accent_color_icon=$(get_tmux_option "@theme_plugin_disk_accent_color_icon" "blue0")

# Mount point to monitor (default: root filesystem)
plugin_disk_mount=$(get_tmux_option "@theme_plugin_disk_mount" "/")

# Display format: "percent", "usage" (used/total), or "free"
plugin_disk_format=$(get_tmux_option "@theme_plugin_disk_format" "percent")

# Cache TTL in seconds (default: 60 seconds - disk usage changes slowly)
CACHE_TTL=$(get_tmux_option "@theme_plugin_disk_cache_ttl" "60")
CACHE_KEY="disk"

export plugin_disk_icon plugin_disk_accent_color plugin_disk_accent_color_icon

# =============================================================================
# Disk Usage Functions
# =============================================================================

# Convert bytes to human readable format
bytes_to_human() {
    local bytes=$1
    
    if [[ $bytes -ge 1099511627776 ]]; then
        # TB
        awk "BEGIN {printf \"%.1fT\", $bytes / 1099511627776}"
    elif [[ $bytes -ge 1073741824 ]]; then
        # GB
        awk "BEGIN {printf \"%.1fG\", $bytes / 1073741824}"
    elif [[ $bytes -ge 1048576 ]]; then
        # MB
        awk "BEGIN {printf \"%.0fM\", $bytes / 1048576}"
    else
        # KB
        awk "BEGIN {printf \"%.0fK\", $bytes / 1024}"
    fi
}

# Get disk usage info
get_disk_info() {
    local mount_point="$1"
    local df_output
    
    # Get disk info using df with 1K blocks for consistency
    # -P for POSIX output format (consistent across systems)
    # Use 'command' builtin to bypass any aliases
    df_output=$(command df -Pk "$mount_point" 2>/dev/null | tail -1)
    
    if [[ -z "$df_output" ]]; then
        printf 'N/A'
        return 1
    fi
    
    local _ total_kb used_kb available_kb percent_used
    read -r _ total_kb used_kb available_kb percent_used _ <<< "$df_output"
    
    # Remove % sign from percent
    percent_used="${percent_used%%%}"
    
    # Validate we got numeric values
    if [[ ! "$total_kb" =~ ^[0-9]+$ ]]; then
        printf 'N/A'
        return 1
    fi
    
    # Convert KB to bytes for human readable conversion
    local total_bytes=$((total_kb * 1024))
    local used_bytes=$((used_kb * 1024))
    local free_bytes=$((available_kb * 1024))
    
    case "$plugin_disk_format" in
        percent)
            printf '%s%%' "$percent_used"
            ;;
        usage)
            printf '%s/%s' "$(bytes_to_human "$used_bytes")" "$(bytes_to_human "$total_bytes")"
            ;;
        free)
            printf '%s' "$(bytes_to_human "$free_bytes")"
            ;;
        *)
            printf '%s%%' "$percent_used"
            ;;
    esac
}

# =============================================================================
# Main Plugin Logic
# =============================================================================

load_plugin() {
    # Check cache first
    local cached_value
    if cached_value=$(cache_get "$CACHE_KEY" "$CACHE_TTL"); then
        printf '%s' "$cached_value"
        return
    fi

    local result
    result=$(get_disk_info "$plugin_disk_mount")
    
    # Only cache valid results
    if [[ -n "$result" && "$result" != "N/A" ]]; then
        cache_set "$CACHE_KEY" "$result"
    fi
    
    printf '%s' "$result"
}

# Only run if executed directly (not sourced)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    load_plugin
fi
