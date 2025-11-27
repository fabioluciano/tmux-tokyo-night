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
    
    # Read context directly from kubeconfig for faster access
    local kubeconfig="${KUBECONFIG:-$HOME/.kube/config}"
    
    if [[ ! -f "$kubeconfig" ]]; then
        printf ''
        return
    fi
    
    local context namespace
    
    # Fast extraction using awk instead of kubectl commands
    # This avoids kubectl's startup overhead
    context=$(awk '/^current-context:/ {print $2; exit}' "$kubeconfig" 2>/dev/null)
    
    if [[ -z "$context" ]]; then
        printf ''
        return
    fi
    
    # Shorten common context name patterns
    context="${context##*@}"  # Remove user@ prefix
    context="${context##*:}"  # Remove cluster prefix
    
    local output="$context"
    
    if [[ "$plugin_kubernetes_show_namespace" == "true" ]]; then
        # Extract namespace for current context using awk (faster than kubectl config view)
        namespace=$(awk -v ctx="$context" '
            /^contexts:/ { in_contexts=1; next }
            in_contexts && /^[^ ]/ { in_contexts=0 }
            in_contexts && /- name:/ && $3 == ctx { found=1; next }
            found && /namespace:/ { print $2; exit }
            found && /^  - name:/ { found=0 }
        ' "$kubeconfig" 2>/dev/null)
        
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

# Only run if executed directly (not sourced)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    load_plugin
fi
