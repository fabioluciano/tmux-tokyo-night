#!/usr/bin/env bash
# =============================================================================
# Plugin: kubernetes
# Description: Display current Kubernetes context and namespace
# Dependencies: kubectl
#
# Display modes:
#   - always: Always show context (if configured)
#   - connected: Only show when cluster is reachable (uses background check)
#   - context: Only show when a context is configured (default)
#
# PERFORMANCE: The "connected" mode now uses background connectivity checks
# to avoid blocking the status bar. Results are cached aggressively.
#
# Configuration options:
#   @theme_plugin_kubernetes_display_mode          - Display mode (default: context)
#   @theme_plugin_kubernetes_show_namespace        - Show namespace (default: false)
#   @theme_plugin_kubernetes_connectivity_timeout  - Timeout for connectivity check in seconds (default: 2)
#   @theme_plugin_kubernetes_connectivity_cache_ttl - Cache TTL for connectivity check (default: 300)
# =============================================================================

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck source=src/defaults.sh
. "$ROOT_DIR/../defaults.sh"
# shellcheck source=src/utils.sh
. "$ROOT_DIR/../utils.sh"
# shellcheck source=src/cache.sh
. "$ROOT_DIR/../cache.sh"

# =============================================================================
# Plugin Configuration
# =============================================================================

# shellcheck disable=SC2034
plugin_kubernetes_icon=$(get_tmux_option "@theme_plugin_kubernetes_icon" "$PLUGIN_KUBERNETES_ICON")
# shellcheck disable=SC2034
plugin_kubernetes_accent_color=$(get_tmux_option "@theme_plugin_kubernetes_accent_color" "$PLUGIN_KUBERNETES_ACCENT_COLOR")
# shellcheck disable=SC2034
plugin_kubernetes_accent_color_icon=$(get_tmux_option "@theme_plugin_kubernetes_accent_color_icon" "$PLUGIN_KUBERNETES_ACCENT_COLOR_ICON")

# Display mode: always, connected, context
plugin_kubernetes_display_mode=$(get_tmux_option "@theme_plugin_kubernetes_display_mode" "$PLUGIN_KUBERNETES_DISPLAY_MODE")

# Show namespace (true/false) - default: false (context only)
plugin_kubernetes_show_namespace=$(get_tmux_option "@theme_plugin_kubernetes_show_namespace" "$PLUGIN_KUBERNETES_SHOW_NAMESPACE")

# Connectivity check settings
plugin_kubernetes_connectivity_timeout=$(get_tmux_option "@theme_plugin_kubernetes_connectivity_timeout" "$PLUGIN_KUBERNETES_CONNECTIVITY_TIMEOUT")
plugin_kubernetes_connectivity_cache_ttl=$(get_tmux_option "@theme_plugin_kubernetes_connectivity_cache_ttl" "$PLUGIN_KUBERNETES_CONNECTIVITY_CACHE_TTL")

# Cache TTL in seconds (default: 30 seconds)
CACHE_TTL=$(get_tmux_option "@theme_plugin_kubernetes_cache_ttl" "$PLUGIN_KUBERNETES_CACHE_TTL")
CACHE_KEY="kubernetes"
CONNECTIVITY_CACHE_KEY="kubernetes_connectivity"
CONNECTIVITY_LOCK_FILE="${CACHE_DIR:-$HOME/.cache/tmux-tokyo-night}/kubernetes_checking.lock"

export plugin_kubernetes_icon plugin_kubernetes_accent_color plugin_kubernetes_accent_color_icon

# =============================================================================
# Kubernetes Functions
# =============================================================================

# -----------------------------------------------------------------------------
# Check if connectivity check is running
# Returns: 0 if running, 1 otherwise
# -----------------------------------------------------------------------------
connectivity_check_is_running() {
    if [[ -f "$CONNECTIVITY_LOCK_FILE" ]]; then
        local lock_age
        lock_age=$(( $(date +%s) - $(stat -f %m "$CONNECTIVITY_LOCK_FILE" 2>/dev/null || stat -c %Y "$CONNECTIVITY_LOCK_FILE" 2>/dev/null || echo 0) ))
        if [[ $lock_age -lt 30 ]]; then
            return 0
        else
            rm -f "$CONNECTIVITY_LOCK_FILE"
        fi
    fi
    return 1
}

# -----------------------------------------------------------------------------
# Run background connectivity check
# -----------------------------------------------------------------------------
run_background_connectivity_check() {
    mkdir -p "$(dirname "$CONNECTIVITY_LOCK_FILE")"
    touch "$CONNECTIVITY_LOCK_FILE"
    
    (
        if kubectl cluster-info --request-timeout="${plugin_kubernetes_connectivity_timeout}s" &>/dev/null; then
            cache_set "$CONNECTIVITY_CACHE_KEY" "connected"
        else
            cache_set "$CONNECTIVITY_CACHE_KEY" "disconnected"
        fi
        rm -f "$CONNECTIVITY_LOCK_FILE"
    ) &>/dev/null &
    
    disown 2>/dev/null || true
}

# -----------------------------------------------------------------------------
# Check if cluster is reachable (with caching and background updates)
# Returns: 0 if connected, 1 otherwise
# -----------------------------------------------------------------------------
check_cluster_connectivity() {
    # Try cache first (within TTL)
    local cached_status
    if cached_status=$(cache_get "$CONNECTIVITY_CACHE_KEY" "$plugin_kubernetes_connectivity_cache_ttl"); then
        [[ "$cached_status" == "connected" ]] && return 0
        return 1
    fi
    
    # Cache expired or missing - trigger background refresh
    if ! connectivity_check_is_running; then
        run_background_connectivity_check
    fi
    
    # Return last known status (even if expired) - be pessimistic if unknown
    # Read raw cache file to get last known status regardless of TTL
    local cache_file="${CACHE_DIR:-$HOME/.cache/tmux-tokyo-night}/${CONNECTIVITY_CACHE_KEY}.cache"
    if [[ -f "$cache_file" ]]; then
        cached_status=$(<"$cache_file")
        [[ "$cached_status" == "connected" ]] && return 0
    fi
    
    # No previous data - assume disconnected (pessimistic)
    return 1
}

# -----------------------------------------------------------------------------
# Get current context from kubeconfig (FAST - no kubectl call)
# Returns: Context name or empty string
# -----------------------------------------------------------------------------
get_current_context() {
    local kubeconfig="${KUBECONFIG:-$HOME/.kube/config}"
    
    [[ ! -f "$kubeconfig" ]] && return
    
    awk '/^current-context:/ {print $2; exit}' "$kubeconfig" 2>/dev/null
}

# -----------------------------------------------------------------------------
# Get kubernetes info (context and optional namespace)
# Returns: Formatted kubernetes info string
# -----------------------------------------------------------------------------
get_k8s_info() {
    # Check if kubectl is available
    if ! command -v kubectl &>/dev/null; then
        return
    fi
    
    local kubeconfig="${KUBECONFIG:-$HOME/.kube/config}"
    
    if [[ ! -f "$kubeconfig" ]]; then
        return
    fi
    
    local context_raw context namespace
    
    # Fast extraction using awk instead of kubectl commands
    context_raw=$(get_current_context)
    
    if [[ -z "$context_raw" ]]; then
        return
    fi
    
    # Shorten common context name patterns for display
    context="${context_raw##*@}"  # Remove user@ prefix
    context="${context##*:}"  # Remove cluster prefix
    
    local output="$context"
    
    if [[ "$plugin_kubernetes_show_namespace" == "true" ]]; then
        # Extract namespace for current context using awk (faster than kubectl config view)
        namespace=$(awk -v ctx="$context_raw" '
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
    # For "connected" mode, check connectivity (non-blocking with background updates)
    if [[ "$plugin_kubernetes_display_mode" == "connected" ]]; then
        if ! check_cluster_connectivity; then
            # Clear the context cache when disconnected to ensure clean state
            cache_set "$CACHE_KEY" ""
            return
        fi
    fi
    
    # Check cache for context/namespace info
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
