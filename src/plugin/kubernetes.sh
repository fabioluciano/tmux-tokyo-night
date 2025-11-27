#!/usr/bin/env bash
# =============================================================================
# Plugin: kubernetes
# Description: Display current Kubernetes context and namespace
# Dependencies: kubectl
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
plugin_kubernetes_icon=$(get_tmux_option "@theme_plugin_kubernetes_icon" "󱃾 ")
# shellcheck disable=SC2034
plugin_kubernetes_accent_color=$(get_tmux_option "@theme_plugin_kubernetes_accent_color" "blue7")
# shellcheck disable=SC2034
plugin_kubernetes_accent_color_icon=$(get_tmux_option "@theme_plugin_kubernetes_accent_color_icon" "blue0")

# Show namespace (true/false)
plugin_kubernetes_show_namespace=$(get_tmux_option "@theme_plugin_kubernetes_show_namespace" "true")

# Cache TTL in seconds (default: 30 seconds)
CACHE_TTL=$(get_tmux_option "@theme_plugin_kubernetes_cache_ttl" "30")
CACHE_KEY="kubernetes"

export plugin_kubernetes_icon plugin_kubernetes_accent_color plugin_kubernetes_accent_color_icon

# =============================================================================
# Kubernetes Functions
# =============================================================================

get_k8s_info() {
    # Check if kubectl is available
    if ! command -v kubectl &>/dev/null; then
        printf ''
        return
    fi
    
    local context namespace
    context=$(kubectl config current-context 2>/dev/null)
    
    if [[ -z "$context" ]]; then
        printf ''
        return
    fi
    
    # Shorten common context name patterns
    context="${context##*@}"  # Remove user@ prefix
    context="${context##*:}"  # Remove cluster prefix
    
    local output="$context"
    
    if [[ "$plugin_kubernetes_show_namespace" == "true" ]]; then
        namespace=$(kubectl config view --minify --output 'jsonpath={..namespace}' 2>/dev/null)
        [[ -z "$namespace" ]] && namespace="default"
        output+="/$namespace"
    fi
    
    printf '%s' "$output"
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
    result=$(get_k8s_info)

    # Update cache
    cache_set "$CACHE_KEY" "$result"
    
    printf '%s' "$result"
}

load_plugin
