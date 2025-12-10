#!/usr/bin/env bash
# Plugin: external_ip - Display external (public) IP address

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$ROOT_DIR/../plugin_bootstrap.sh"

plugin_init "external_ip"

get_ip() {
    command -v curl &>/dev/null || return 1
    local ip=$(curl -s --connect-timeout 3 --max-time 5 https://api.ipify.org 2>/dev/null)
    [[ -n "$ip" ]] && printf '%s' "$ip"
}

plugin_get_type() { printf 'conditional'; }

load_plugin() {
    local cached
    if cached=$(cache_get "$CACHE_KEY" "$CACHE_TTL"); then
        printf '%s' "$cached"
        return 0
    fi

    local ip=$(get_ip)
    [[ -z "$ip" ]] && return 0

    cache_set "$CACHE_KEY" "$ip"
    printf '%s' "$ip"
}

[[ "${BASH_SOURCE[0]}" == "${0}" ]] && load_plugin || true
