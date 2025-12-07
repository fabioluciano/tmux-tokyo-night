#!/usr/bin/env bash
# Cloud provider context plugin (AWS/GCP/Azure)
# Dependencies: aws/gcloud/az CLI (optional, reads from config files)
#
# Configuration options:
#   @powerkit_plugin_cloud_icon              - Default icon (default: ☁️)
#   @powerkit_plugin_cloud_accent_color      - Default accent color
#   @powerkit_plugin_cloud_accent_color_icon - Default icon accent color
#   @powerkit_plugin_cloud_cache_ttl         - Cache time in seconds (default: 30)
#
# Provider-specific icons:
#   @powerkit_plugin_cloud_icon_aws          - AWS icon (default: )
#   @powerkit_plugin_cloud_icon_gcp          - GCP icon (default: 󱇶)
#   @powerkit_plugin_cloud_icon_azure        - Azure icon (default: 󰠅)
#   @powerkit_plugin_cloud_icon_multi        - Multiple providers icon (default: ☁️)
#
# Display options:
#   @powerkit_plugin_cloud_providers         - Providers to check: aws,gcp,azure or "all" (default: all)
#   @powerkit_plugin_cloud_format            - Format: short, full, icon-only (default: short)
#   @powerkit_plugin_cloud_show_account      - Show account/project ID: true, false (default: false)
#   @powerkit_plugin_cloud_show_region       - Show region: true, false (default: true)
#   @powerkit_plugin_cloud_max_length        - Max length for display (default: 40)
#   @powerkit_plugin_cloud_separator         - Separator between providers (default: " | ")
#
# Display threshold options:
#   @powerkit_plugin_cloud_display_condition - Condition: always (default)
#
# Warning colors (for production detection):
#   @powerkit_plugin_cloud_warn_on_prod      - Highlight production: true, false (default: true)
#   @powerkit_plugin_cloud_prod_keywords     - Keywords for prod detection (default: "prod,production,prd")
#   @powerkit_plugin_cloud_prod_accent_color - Color for prod environments (default: red)
#
# Examples:
#   # Show only AWS with region
#   set -g @powerkit_plugin_cloud_providers "aws"
#   set -g @powerkit_plugin_cloud_show_region "true"
#
#   # Compact format - icon only
#   set -g @powerkit_plugin_cloud_format "icon-only"
#
#   # Full details with account ID
#   set -g @powerkit_plugin_cloud_format "full"
#   set -g @powerkit_plugin_cloud_show_account "true"
#
#   # Highlight production environments
#   set -g @powerkit_plugin_cloud_warn_on_prod "true"
#   set -g @powerkit_plugin_cloud_prod_keywords "prod,production,live"
# =============================================================================

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck source=src/plugin_bootstrap.sh
. "$ROOT_DIR/../plugin_bootstrap.sh"

# =============================================================================
# Plugin Configuration
# =============================================================================

# Initialize cache (DRY - sets CACHE_KEY and CACHE_TTL automatically)
plugin_init "cloud"

# =============================================================================
# AWS Detection Functions
# =============================================================================

get_aws_profile() {
    # Priority: 1. AWS_PROFILE env var, 2. AWS_DEFAULT_PROFILE, 3. config file default
    if [[ -n "${AWS_PROFILE:-}" ]]; then
        echo "$AWS_PROFILE"
        return 0
    fi
    
    if [[ -n "${AWS_DEFAULT_PROFILE:-}" ]]; then
        echo "$AWS_DEFAULT_PROFILE"
        return 0
    fi
    
    # Check AWS config for default profile
    local aws_config="${AWS_CONFIG_FILE:-$HOME/.aws/config}"
    if [[ -f "$aws_config" ]]; then
        # Look for [default] or [profile default]
        if grep -q "^\[default\]" "$aws_config" 2>/dev/null || \
           grep -q "^\[profile default\]" "$aws_config" 2>/dev/null; then
            echo "default"
            return 0
        fi
    fi
    
    return 1
}

get_aws_region() {
    # Priority: 1. AWS_REGION, 2. AWS_DEFAULT_REGION, 3. config file, 4. aws configure
    if [[ -n "${AWS_REGION:-}" ]]; then
        echo "$AWS_REGION"
        return 0
    fi
    
    if [[ -n "${AWS_DEFAULT_REGION:-}" ]]; then
        echo "$AWS_DEFAULT_REGION"
        return 0
    fi
    
    local profile="${1:-default}"
    local aws_config="${AWS_CONFIG_FILE:-$HOME/.aws/config}"
    
    if [[ -f "$aws_config" ]]; then
        # Extract region from config file
        local region
        region=$(awk -v profile="$profile" '
            /^\[profile / { in_profile=0 }
            /^\[default\]/ { in_profile=(profile=="default") }
            /^\[profile '"$profile"'\]/ { in_profile=1 }
            in_profile && /^region[[:space:]]*=/ { sub(/^region[[:space:]]*=[[:space:]]*/, ""); print; exit }
        ' "$aws_config")
        
        if [[ -n "$region" ]]; then
            echo "$region"
            return 0
        fi
    fi
    
    return 1
}

get_aws_account() {
    # Try to get account ID from STS (requires aws cli and credentials)
    if command -v aws >/dev/null 2>&1; then
        local account_id
        account_id=$(aws sts get-caller-identity --query Account --output text 2>/dev/null)
        if [[ -n "$account_id" ]]; then
            echo "$account_id"
            return 0
        fi
    fi
    
    return 1
}

get_aws_context() {
    local profile region account
    
    profile=$(get_aws_profile) || return 1
    region=$(get_aws_region "$profile")
    
    local show_account show_region
    show_account=$(get_cached_option "@powerkit_plugin_cloud_show_account" "false")
    show_region=$(get_cached_option "@powerkit_plugin_cloud_show_region" "true")
    
    if [[ "$show_account" == "true" ]]; then
        account=$(get_aws_account)
    fi
    
    # Build output
    local output="aws:$profile"
    
    if [[ -n "$region" ]] && [[ "$show_region" == "true" ]]; then
        output="$output@$region"
    fi
    
    if [[ -n "$account" ]] && [[ "$show_account" == "true" ]]; then
        output="$output:${account:0:4}***"
    fi
    
    echo "$output"
}

# =============================================================================
# GCP Detection Functions
# =============================================================================

get_gcp_project() {
    # Priority: 1. CLOUDSDK_CORE_PROJECT, 2. gcloud config, 3. GOOGLE_CLOUD_PROJECT
    if [[ -n "${CLOUDSDK_CORE_PROJECT:-}" ]]; then
        echo "$CLOUDSDK_CORE_PROJECT"
        return 0
    fi
    
    if [[ -n "${GOOGLE_CLOUD_PROJECT:-}" ]]; then
        echo "$GOOGLE_CLOUD_PROJECT"
        return 0
    fi
    
    # Read from gcloud config
    local gcloud_config="$HOME/.config/gcloud/configurations/config_default"
    if [[ -f "$gcloud_config" ]]; then
        local project
        project=$(awk -F '= ' '/^project = / {print $2}' "$gcloud_config" 2>/dev/null)
        if [[ -n "$project" ]]; then
            echo "$project"
            return 0
        fi
    fi
    
    # Try gcloud command if available
    if command -v gcloud >/dev/null 2>&1; then
        local project
        project=$(gcloud config get-value project 2>/dev/null)
        if [[ -n "$project" ]] && [[ "$project" != "(unset)" ]]; then
            echo "$project"
            return 0
        fi
    fi
    
    return 1
}

get_gcp_region() {
    # Priority: 1. CLOUDSDK_COMPUTE_REGION, 2. gcloud config
    if [[ -n "${CLOUDSDK_COMPUTE_REGION:-}" ]]; then
        echo "$CLOUDSDK_COMPUTE_REGION"
        return 0
    fi
    
    local gcloud_config="$HOME/.config/gcloud/configurations/config_default"
    if [[ -f "$gcloud_config" ]]; then
        local region
        region=$(awk -F '= ' '/^region = / {print $2}' "$gcloud_config" 2>/dev/null)
        if [[ -n "$region" ]]; then
            echo "$region"
            return 0
        fi
    fi
    
    if command -v gcloud >/dev/null 2>&1; then
        local region
        region=$(gcloud config get-value compute/region 2>/dev/null)
        if [[ -n "$region" ]] && [[ "$region" != "(unset)" ]]; then
            echo "$region"
            return 0
        fi
    fi
    
    return 1
}

get_gcp_context() {
    local project region
    
    project=$(get_gcp_project) || return 1
    
    local show_region
    show_region=$(get_cached_option "@powerkit_plugin_cloud_show_region" "true")
    
    if [[ "$show_region" == "true" ]]; then
        region=$(get_gcp_region)
    fi
    
    # Build output
    local output="gcp:$project"
    
    if [[ -n "$region" ]]; then
        output="$output@$region"
    fi
    
    echo "$output"
}

# =============================================================================
# Azure Detection Functions
# =============================================================================

get_azure_subscription() {
    # Priority: 1. AZURE_SUBSCRIPTION_ID, 2. az config
    if [[ -n "${AZURE_SUBSCRIPTION_ID:-}" ]]; then
        echo "$AZURE_SUBSCRIPTION_ID"
        return 0
    fi
    
    # Read from azure config
    local azure_config="$HOME/.azure/azureProfile.json"
    if [[ -f "$azure_config" ]] && command -v jq >/dev/null 2>&1; then
        local sub_name
        sub_name=$(jq -r '.subscriptions[] | select(.isDefault==true) | .name' "$azure_config" 2>/dev/null | head -1)
        if [[ -n "$sub_name" ]]; then
            echo "$sub_name"
            return 0
        fi
    fi
    
    # Try az command if available
    if command -v az >/dev/null 2>&1; then
        local sub_name
        sub_name=$(az account show --query name -o tsv 2>/dev/null)
        if [[ -n "$sub_name" ]]; then
            echo "$sub_name"
            return 0
        fi
    fi
    
    return 1
}

get_azure_location() {
    # Try to get default location from config
    if command -v az >/dev/null 2>&1; then
        local location
        location=$(az config get defaults.location --query value -o tsv 2>/dev/null)
        if [[ -n "$location" ]] && [[ "$location" != "None" ]]; then
            echo "$location"
            return 0
        fi
    fi
    
    return 1
}

get_azure_context() {
    local subscription location
    
    subscription=$(get_azure_subscription) || return 1
    
    local show_region
    show_region=$(get_cached_option "@powerkit_plugin_cloud_show_region" "true")
    
    if [[ "$show_region" == "true" ]]; then
        location=$(get_azure_location)
    fi
    
    # Build output
    local output="azure:$subscription"
    
    if [[ -n "$location" ]]; then
        output="$output@$location"
    fi
    
    echo "$output"
}

# =============================================================================
# Production Detection
# =============================================================================

is_production_context() {
    local context="$1"
    local keywords
    
    keywords=$(get_cached_option "@powerkit_plugin_cloud_prod_keywords" "$POWERKIT_PLUGIN_CLOUD_PROD_KEYWORDS")
    
    # Convert comma-separated keywords to array
    IFS=',' read -ra keywords_array <<< "$keywords"
    
    # Check if context contains any production keyword (case insensitive)
    local keyword
    for keyword in "${keywords_array[@]}"; do
        keyword=$(echo "$keyword" | xargs) # trim whitespace
        if [[ "${context,,}" == *"${keyword,,}"* ]]; then
            return 0
        fi
    done
    
    return 1
}

# =============================================================================
# Main Detection Logic
# =============================================================================

get_cloud_contexts() {
    local providers contexts=()
    local aws_ctx gcp_ctx azure_ctx
    
    providers=$(get_cached_option "@powerkit_plugin_cloud_providers" "$POWERKIT_PLUGIN_CLOUD_PROVIDERS")
    
    # Normalize "all" to comma-separated list
    if [[ "$providers" == "all" ]]; then
        providers="aws,gcp,azure"
    fi
    
    # Split providers and check each
    IFS=',' read -ra provider_array <<< "$providers"
    
    for provider in "${provider_array[@]}"; do
        provider=$(echo "$provider" | xargs | tr '[:upper:]' '[:lower:]') # trim and lowercase
        
        case "$provider" in
            aws)
                if aws_ctx=$(get_aws_context); then
                    contexts+=("$aws_ctx")
                fi
                ;;
            gcp)
                if gcp_ctx=$(get_gcp_context); then
                    contexts+=("$gcp_ctx")
                fi
                ;;
            azure)
                if azure_ctx=$(get_azure_context); then
                    contexts+=("$azure_ctx")
                fi
                ;;
        esac
    done
    
    # Return joined contexts
    if [[ ${#contexts[@]} -eq 0 ]]; then
        return 1
    fi
    
    local separator
    separator=$(get_cached_option "@powerkit_plugin_cloud_separator" "$POWERKIT_PLUGIN_CLOUD_SEPARATOR")
    
    local IFS="$separator"
    echo "${contexts[*]}"
}

# =============================================================================
# Plugin Interface Implementation
# =============================================================================

# Function to inform the plugin type to the renderer
plugin_get_type() {
    printf 'conditional'
}

plugin_get_display_info() {
    local content="$1"
    local show="1"
    local accent=""
    local accent_icon=""
    local icon=""
    
    # Check for production and set warning color
    local warn_on_prod
    warn_on_prod=$(get_cached_option "@powerkit_plugin_cloud_warn_on_prod" "$POWERKIT_PLUGIN_CLOUD_WARN_ON_PROD")
    
    if [[ "$warn_on_prod" == "true" ]] && is_production_context "$content"; then
        accent=$(get_cached_option "@powerkit_plugin_cloud_prod_accent_color" "$POWERKIT_PLUGIN_CLOUD_PROD_ACCENT_COLOR")
        accent_icon="$accent"
    fi
    
    # Determine icon based on providers in content
    local icon_aws icon_gcp icon_azure icon_multi
    icon_aws=$(get_cached_option "@powerkit_plugin_cloud_icon_aws" "$POWERKIT_PLUGIN_CLOUD_ICON_AWS")
    icon_gcp=$(get_cached_option "@powerkit_plugin_cloud_icon_gcp" "$POWERKIT_PLUGIN_CLOUD_ICON_GCP")
    icon_azure=$(get_cached_option "@powerkit_plugin_cloud_icon_azure" "$POWERKIT_PLUGIN_CLOUD_ICON_AZURE")
    icon_multi=$(get_cached_option "@powerkit_plugin_cloud_icon_multi" "$POWERKIT_PLUGIN_CLOUD_ICON_MULTI")
    
    # Count how many providers are in the content
    local provider_count=0
    [[ "$content" == *"aws:"* ]] && ((provider_count++)) && icon="$icon_aws"
    [[ "$content" == *"gcp:"* ]] && ((provider_count++)) && icon="$icon_gcp"
    [[ "$content" == *"azure:"* ]] && ((provider_count++)) && icon="$icon_azure"
    
    # Use multi-provider icon if more than one
    if [[ $provider_count -gt 1 ]]; then
        icon="$icon_multi"
    fi
    
    build_display_info "$show" "$accent" "$accent_icon" "$icon"
}

# =============================================================================
# Main Plugin Logic
# =============================================================================

load_plugin() {
    # Check cache first
    local cached_value
    if cached_value=$(cache_get "$CACHE_KEY" "$CACHE_TTL"); then
        printf '%s' "$cached_value"
        return 0
    fi
    
    # Get cloud contexts
    local contexts
    contexts=$(get_cloud_contexts) || return 0
    
    # Apply format option
    local format max_length
    format=$(get_cached_option "@powerkit_plugin_cloud_format" "$POWERKIT_PLUGIN_CLOUD_FORMAT")
    max_length=$(get_cached_option "@powerkit_plugin_cloud_max_length" "$POWERKIT_PLUGIN_CLOUD_MAX_LENGTH")
    
    local result="$contexts"
    
    # Apply format transformations
    case "$format" in
        icon-only)
            # Return empty - icon will be shown via plugin_get_display_info
            result=""
            # Store in cache for icon detection
            cache_set "$CACHE_KEY" "$contexts"
            return 0
            ;;
        short)
            # Remove provider prefix for cleaner display
            result=$(echo "$result" | sed 's/aws://g; s/gcp://g; s/azure://g')
            ;;
        full)
            # Keep full format (default)
            ;;
    esac
    
    # Truncate if needed
    if [[ ${#result} -gt $max_length ]]; then
        result="${result:0:$max_length}\u2026"
    fi
    
    cache_set "$CACHE_KEY" "$contexts"
    printf '%s' "$result"
}

# Only run if executed directly (not sourced)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    load_plugin
fi
