#!/usr/bin/env bash
# =============================================================================
# Plugin: memory
# Description: Display memory usage percentage
# Dependencies: None (uses /proc/meminfo on Linux, vm_stat on macOS)
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
plugin_memory_icon=$(get_tmux_option "@theme_plugin_memory_icon" " ")
# shellcheck disable=SC2034
plugin_memory_accent_color=$(get_tmux_option "@theme_plugin_memory_accent_color" "blue7")
# shellcheck disable=SC2034
plugin_memory_accent_color_icon=$(get_tmux_option "@theme_plugin_memory_accent_color_icon" "blue0")

# Cache TTL in seconds
CACHE_TTL=5
CACHE_KEY="memory"

# Display format: "percent" or "usage" (e.g., "4.2G/16G")
plugin_memory_format=$(get_tmux_option "@theme_plugin_memory_format" "percent")

export plugin_memory_icon plugin_memory_accent_color plugin_memory_accent_color_icon

# =============================================================================
# Memory Calculation Functions
# =============================================================================

# Convert bytes to human readable format
bytes_to_human() {
    local bytes=$1
    local gb=$((bytes / 1024 / 1024 / 1024))
    local mb=$((bytes / 1024 / 1024))
    
    if [[ $gb -gt 0 ]]; then
        printf '%.1fG' "$(echo "scale=1; $bytes / 1024 / 1024 / 1024" | bc 2>/dev/null || echo "$gb")"
    else
        printf '%dM' "$mb"
    fi
}

# Get memory usage on Linux
get_memory_linux() {
    local mem_total mem_available mem_used percent
    
    mem_total=$(grep '^MemTotal:' /proc/meminfo | awk '{print $2}')
    mem_available=$(grep '^MemAvailable:' /proc/meminfo | awk '{print $2}')
    
    # MemAvailable might not exist on older kernels
    if [[ -z "$mem_available" ]]; then
        local mem_free mem_buffers mem_cached
        mem_free=$(grep '^MemFree:' /proc/meminfo | awk '{print $2}')
        mem_buffers=$(grep '^Buffers:' /proc/meminfo | awk '{print $2}')
        mem_cached=$(grep '^Cached:' /proc/meminfo | awk '{print $2}')
        mem_available=$((mem_free + mem_buffers + mem_cached))
    fi
    
    mem_used=$((mem_total - mem_available))
    percent=$(( (mem_used * 100) / mem_total ))
    
    if [[ "$plugin_memory_format" == "usage" ]]; then
        local used_bytes=$((mem_used * 1024))
        local total_bytes=$((mem_total * 1024))
        printf '%s/%s' "$(bytes_to_human $used_bytes)" "$(bytes_to_human $total_bytes)"
    else
        printf '%d%%' "$percent"
    fi
}

# Get memory usage on macOS
get_memory_macos() {
    local page_size mem_total pages_free pages_active pages_inactive pages_speculative pages_wired
    local mem_used percent
    
    page_size=$(pagesize 2>/dev/null || sysctl -n hw.pagesize)
    mem_total=$(sysctl -n hw.memsize)
    
    # Get memory pages from vm_stat
    local vm_stat_output
    vm_stat_output=$(vm_stat)
    
    local pages_active pages_wired
    pages_active=$(echo "$vm_stat_output" | grep "Pages active:" | awk '{print $3}' | tr -d '.')
    pages_wired=$(echo "$vm_stat_output" | grep "Pages wired down:" | awk '{print $4}' | tr -d '.')
    
    # Calculate used memory (active + wired)
    local pages_used=$((pages_active + pages_wired))
    mem_used=$((pages_used * page_size))
    
    percent=$(( (mem_used * 100) / mem_total ))
    
    if [[ "$plugin_memory_format" == "usage" ]]; then
        printf '%s/%s' "$(bytes_to_human "$mem_used")" "$(bytes_to_human "$mem_total")"
    else
        printf '%d%%' "$percent"
    fi
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
    case "$(uname -s)" in
        Linux*)
            result=$(get_memory_linux)
            ;;
        Darwin*)
            result=$(get_memory_macos)
            ;;
        *)
            result="N/A"
            ;;
    esac

    # Update cache
    cache_set "$CACHE_KEY" "$result"
    
    printf '%s' "$result"
}

load_plugin
