#!/usr/bin/env bash
# =============================================================================
# Plugin: disk
# Description: Display disk usage for a specified mount point
# Dependencies: df
# =============================================================================

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck source=src/plugin_bootstrap.sh
. "$ROOT_DIR/../plugin_bootstrap.sh"

# =============================================================================
# Plugin Configuration
# =============================================================================

# Initialize cache (DRY - sets CACHE_KEY and CACHE_TTL automatically)
plugin_init "disk"

# Plugin-specific settings (not common to all plugins)
plugin_disk_mount=$(get_tmux_option "@powerkit_plugin_disk_mount" "$POWERKIT_PLUGIN_DISK_MOUNT")
plugin_disk_format=$(get_tmux_option "@powerkit_plugin_disk_format" "$POWERKIT_PLUGIN_DISK_FORMAT")

# =============================================================================
# Disk Usage Functions
# =============================================================================

# Convert bytes to human readable format
bytes_to_human() {
    local bytes=$1
    
    if [[ $bytes -ge $POWERKIT_BYTE_TB ]]; then
        # TB
        awk "BEGIN {printf \"%.1fT\", $bytes / $POWERKIT_BYTE_TB}"
    elif [[ $bytes -ge $POWERKIT_BYTE_GB ]]; then
        # GB
        awk "BEGIN {printf \"%.1fG\", $bytes / $POWERKIT_BYTE_GB}"
    elif [[ $bytes -ge $POWERKIT_BYTE_MB ]]; then
        # MB
        awk "BEGIN {printf \"%.0fM\", $bytes / $POWERKIT_BYTE_MB}"
    else
        # KB
        awk "BEGIN {printf \"%.0fK\", $bytes / $POWERKIT_BYTE_KB}"
    fi
}

# Get disk usage info
get_disk_info() {
    local mount_point="$1"
    
    # Single awk call to parse df output efficiently
    command df -Pk "$mount_point" 2>/dev/null | awk '
        NR==2 {
            total_kb = $2
            used_kb = $3
            available_kb = $4
            percent_used = $5
            
            # Remove % sign and validate
            gsub(/%/, "", percent_used)
            
            if (total_kb > 0 && percent_used >= 0) {
                total_bytes = total_kb * '$POWERKIT_BYTE_KB'
                used_bytes = used_kb * '$POWERKIT_BYTE_KB'
                free_bytes = available_kb * '$POWERKIT_BYTE_KB'
                
                format = "'$plugin_disk_format'"
                if (format == "usage") {
                    printf "%.1f/%.1f", used_bytes/'$POWERKIT_BYTE_GB', total_bytes/'$POWERKIT_BYTE_GB'
                } else if (format == "free") {
                    if (free_bytes >= '$POWERKIT_BYTE_TB') printf "%.1fT", free_bytes/'$POWERKIT_BYTE_TB'
                    else if (free_bytes >= '$POWERKIT_BYTE_GB') printf "%.1fG", free_bytes/'$POWERKIT_BYTE_GB'
                    else if (free_bytes >= '$POWERKIT_BYTE_MB') printf "%.0fM", free_bytes/'$POWERKIT_BYTE_MB'
                    else printf "%.0fK", free_bytes/'$POWERKIT_BYTE_KB'
                } else {
                    printf "%s%%", percent_used
                }
            } else {
                print "N/A"
                exit 1
            }
        }'
}

# =============================================================================
# Plugin Interface Implementation
# =============================================================================

# Note: plugin_get_display_info() removed - now handled centrally by
# apply_powerkit_plugin_config() in render_plugins.sh using defaults.sh values

# Function to inform the plugin type to the renderer
plugin_get_type() {
    printf 'static'
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
