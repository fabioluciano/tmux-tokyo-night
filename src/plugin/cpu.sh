#!/usr/bin/env bash
# =============================================================================
# Plugin: cpu
# Description: Display CPU usage percentage
# Dependencies: None (uses /proc/stat on Linux, vm_stat on macOS)
# =============================================================================

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck source=src/plugin_bootstrap.sh
. "$ROOT_DIR/../plugin_bootstrap.sh"

# =============================================================================
# Plugin Configuration
# =============================================================================

# Initialize cache (DRY - sets CACHE_KEY and CACHE_TTL automatically)
plugin_init "cpu"

# =============================================================================
# CPU Calculation Functions
# =============================================================================

# Get CPU usage on Linux using /proc/stat
get_cpu_linux() {
    local cpu_line
    local -a cpu_values
    local idle_prev total_prev idle_curr total_curr
    local diff_idle diff_total cpu_usage

    # Read first measurement
    cpu_line=$(command grep '^cpu ' /proc/stat)
    read -ra cpu_values <<< "${cpu_line#cpu }"
    
    idle_prev=${cpu_values[3]}
    total_prev=0
    for val in "${cpu_values[@]}"; do
        total_prev=$((total_prev + val))
    done

    # Wait a bit for second measurement
    sleep "$POWERKIT_TIMING_CPU_SAMPLE"

    # Read second measurement
    cpu_line=$(command grep '^cpu ' /proc/stat)
    read -ra cpu_values <<< "${cpu_line#cpu }"
    
    idle_curr=${cpu_values[3]}
    total_curr=0
    for val in "${cpu_values[@]}"; do
        total_curr=$((total_curr + val))
    done

    # Calculate difference
    diff_idle=$((idle_curr - idle_prev))
    diff_total=$((total_curr - total_prev))

    # Calculate CPU usage percentage
    if [[ $diff_total -gt 0 ]]; then
        cpu_usage=$(( (1000 * (diff_total - diff_idle) / diff_total + 5) / 10 ))
    else
        cpu_usage=0
    fi

    printf '%d' "$cpu_usage"
}

# Get CPU usage on macOS using iostat (no sleep needed, instant reading)
get_cpu_macos() {
    local cpu_usage
    
    # Use iostat which provides instant CPU utilization
    # Last line contains current stats (no historical average)
    cpu_usage=$(iostat -c "$POWERKIT_IOSTAT_COUNT" 2>/dev/null | tail -1 | awk -v base="$POWERKIT_IOSTAT_BASELINE" -v field="$POWERKIT_IOSTAT_CPU_FIELD" '{print base-$field}' | awk '{printf "%.0f", $1}')
    
    # Fallback to ps if iostat not available
    if [[ -z "$cpu_usage" || "$cpu_usage" == "100" ]]; then
        local num_cores
        num_cores=$(sysctl -n hw.ncpu 2>/dev/null || echo 1)
        
        # Use more efficient ps with reduced process scanning
        cpu_usage=$(command ps -axo %cpu | command awk -v cores="$num_cores" -v limit="$POWERKIT_PERF_CPU_PROCESS_LIMIT" '
            NR>1 && NR<=limit {sum+=$1}  # Only scan first N processes for performance
            END {
                avg = sum / cores
                if (avg > 100) avg = 100
                printf "%.0f", avg
            }
        ')
    fi
    
    printf '%s' "${cpu_usage:-0}"
}

# =============================================================================
# Plugin Interface Implementation
# =============================================================================

# Function to inform the plugin type to the renderer
plugin_get_type() {
    printf 'static'
}

# This function is called by plugin_helpers.sh to get display decisions
# Output format: "show:accent:accent_icon:icon"
#
# Configuration options:
#   @powerkit_plugin_cpu_display_condition    - Condition: le, lt, ge, gt, eq, always
# REMOVED: plugin_get_display_info() - Now using centralized theme-controlled system

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
        result=$(get_cpu_linux)
    elif is_macos; then
        result=$(get_cpu_macos)
    else
        result="N/A"
    fi

    # Add percentage symbol
    if [[ "$result" != "N/A" ]]; then
        result="${result}%"
    fi

    # Update cache
    cache_set "$CACHE_KEY" "$result"
    
    printf '%s' "$result"
}

# Only run if executed directly (not sourced)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    load_plugin
fi
