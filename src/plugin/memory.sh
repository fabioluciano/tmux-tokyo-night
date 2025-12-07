#!/usr/bin/env bash
# =============================================================================
# Plugin: memory
# Description: Display memory usage percentage
# Dependencies: None (uses /proc/meminfo on Linux, vm_stat on macOS)
# =============================================================================

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck source=src/plugin_bootstrap.sh
. "$ROOT_DIR/../plugin_bootstrap.sh"

# =============================================================================
# Plugin Configuration
# =============================================================================

# Initialize cache (DRY - sets CACHE_KEY and CACHE_TTL automatically)
plugin_init "memory"

# Display format: "percent" or "usage" (e.g., "4.2G/16G")
plugin_memory_format=$(get_tmux_option "@powerkit_plugin_memory_format" "$POWERKIT_PLUGIN_MEMORY_FORMAT")

# =============================================================================
# Memory Calculation Functions
# =============================================================================

# Convert bytes to human readable format
bytes_to_human() {
    local bytes=$1
    local gb
    
    # 1 GiB in bytes (1024^3) 
    gb=$((bytes / 1073741824))
    
    if [[ $gb -gt 0 ]]; then
        # Use awk for floating point (faster than bc and more portable)
        awk -v b="$bytes" 'BEGIN {printf "%.1fG", b / 1073741824}'
    else
        # Show in MB if less than 1 GB
        local mb=$((bytes / POWERKIT_BYTE_MB)) # 1 MiB in bytes
        printf '%dM' "$mb"
    fi
}

# Get memory usage on Linux
get_memory_linux() {
    local mem_total mem_available mem_used percent
    
    # Single awk call to read all memory values at once (much faster)
    local mem_info
    mem_info=$(awk '
        /^MemTotal:/ {total=$2}
        /^MemAvailable:/ {available=$2}
        /^MemFree:/ {free=$2}
        /^Buffers:/ {buffers=$2}
        /^Cached:/ {cached=$2}
        END {
            if (available > 0) {
                print total, available
            } else {
                print total, (free + buffers + cached)
            }
        }
    ' /proc/meminfo)
    
    read -r mem_total mem_available <<< "$mem_info"
    
    mem_used=$((mem_total - mem_available))
    percent=$(( (mem_used * 100) / mem_total ))
    
    if [[ "$plugin_memory_format" == "usage" ]]; then
        local used_bytes=$((mem_used * POWERKIT_BYTE_KB))
        local total_bytes=$((mem_total * POWERKIT_BYTE_KB))
        printf '%s/%s' "$(bytes_to_human $used_bytes)" "$(bytes_to_human $total_bytes)"
    else
        printf '%d%%' "$percent"
    fi
}

# Get memory usage on macOS
get_memory_macos() {
    local page_size mem_total mem_used percent
    
    # Try memory_pressure first (most accurate, matches Activity Monitor)
    local free_percent
    free_percent=$(memory_pressure 2>/dev/null | awk '/System-wide memory free percentage:/ {print $5}' | tr -d '%')
    
    if [[ -n "$free_percent" && "$free_percent" =~ ^[0-9]+$ ]]; then
        percent=$((100 - free_percent))
        
        if [[ "$plugin_memory_format" == "usage" ]]; then
            mem_total=$(sysctl -n hw.memsize 2>/dev/null || echo 0)
            mem_used=$((mem_total * percent / 100))
            printf '%s/%s' "$(bytes_to_human "$mem_used")" "$(bytes_to_human "$mem_total")"
        else
            printf '%d%%' "$percent"
        fi
        return
    fi
    
    # Fallback to vm_stat calculation
    page_size=$(sysctl -n hw.pagesize 2>/dev/null || echo 4096)
    mem_total=$(sysctl -n hw.memsize 2>/dev/null || echo 0)
    
    # Calculate app memory (active + wired) - most relevant for user
    local pages_used
    pages_used=$(vm_stat | awk '
        /Pages active:/ {active = $3; gsub(/\./, "", active)}
        /Pages wired down:/ {wired = $4; gsub(/\./, "", wired)}
        END {print active + wired}
    ')
    
    mem_used=$((pages_used * page_size))
    percent=$(( (mem_used * 100) / mem_total ))
    
    if [[ "$plugin_memory_format" == "usage" ]]; then
        printf '%s/%s' "$(bytes_to_human "$mem_used")" "$(bytes_to_human "$mem_total")"
    else
        printf '%d%%' "$percent"
    fi
}

# =============================================================================
# Plugin Interface Implementation
# =============================================================================

# This function is called by plugin_helpers.sh to get display decisions
# Output format: "show:accent:accent_icon:icon"
#
# REMOVED: plugin_get_display_info() - Now using centralized theme-controlled system

# =============================================================================
# Plugin Interface Implementation
# =============================================================================

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
    # Use cached OS detection from utils.sh
    if is_linux; then
        result=$(get_memory_linux)
    elif is_macos; then
        result=$(get_memory_macos)
    else
        result="N/A"
    fi

    # Update cache
    cache_set "$CACHE_KEY" "$result"
    
    printf '%s' "$result"
}

# Only run if executed directly (not sourced)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    load_plugin
fi
