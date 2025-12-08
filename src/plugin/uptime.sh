#!/usr/bin/env bash
# Plugin: uptime - Display system uptime

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$ROOT_DIR/../plugin_bootstrap.sh"

plugin_init "uptime"

plugin_get_type() { printf 'static'; }

format_uptime() {
    local seconds=$1
    local days=$((seconds / 86400))
    local hours=$(( (seconds % 86400) / 3600 ))
    local minutes=$(( (seconds % 3600) / 60 ))
    
    if [[ $days -gt 0 ]]; then
        printf '%dd %dh' "$days" "$hours"
    elif [[ $hours -gt 0 ]]; then
        printf '%dh %dm' "$hours" "$minutes"
    else
        printf '%dm' "$minutes"
    fi
}

get_uptime_linux() {
    local uptime_seconds
    uptime_seconds=$(awk '{printf "%d", $1}' /proc/uptime 2>/dev/null)
    format_uptime "$uptime_seconds"
}

get_uptime_macos() {
    local uptime_seconds
    uptime_seconds=$(sysctl -n kern.boottime 2>/dev/null | awk -v current="$(date +%s)" '
        /sec =/ {gsub(/[{},:=]/," "); for(i=1;i<=NF;i++) if($i=="sec") {print current - $(i+1); exit}}')
    format_uptime "$uptime_seconds"
}

load_plugin() {
    local cached_value
    if cached_value=$(cache_get "$CACHE_KEY" "$CACHE_TTL"); then
        printf '%s' "$cached_value"
        return
    fi

    local result
    is_linux && result=$(get_uptime_linux)
    is_macos && result=$(get_uptime_macos)
    [[ -z "$result" ]] && result="N/A"

    cache_set "$CACHE_KEY" "$result"
    printf '%s' "$result"
}

[[ "${BASH_SOURCE[0]}" == "${0}" ]] && load_plugin || true
