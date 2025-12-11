#!/usr/bin/env bash
# Plugin: cloudstatus - Monitor cloud provider status

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$ROOT_DIR/../plugin_bootstrap.sh"

plugin_init "cloudstatus"

plugin_get_type() { printf 'conditional'; }

# =============================================================================
# Cloud Provider Configuration
# =============================================================================

# Provider definitions: name|api_url|parser_type|icon
declare -A CLOUD_PROVIDERS=(
    # Major Cloud Providers
    ["aws"]="AWS|https://status.aws.amazon.com/rss/all.rss|aws_rss|󰸏"
    ["azure"]="Azure|https://azure.status.microsoft/en-us/status/feed/|azure_rss|󰠅"
    ["gcp"]="GCP|https://status.cloud.google.com/incidents.json|gcp|󱇶"

    # CDN & Infrastructure
    ["cloudflare"]="CF|https://www.cloudflarestatus.com/api/v2/status.json|statuspage|󰸝"

    # Platform as a Service
    ["heroku"]="Heroku|https://status.heroku.com/api/v4/current-status|heroku|󰪸"
    ["vercel"]="Vercel|https://www.vercel-status.com/api/v2/status.json|statuspage|▲"
    ["netlify"]="Netlify|https://www.netlifystatus.com/api/v2/status.json|statuspage|󰻃"
    ["digitalocean"]="DO|https://status.digitalocean.com/api/v2/status.json|statuspage|🌊"
    ["linode"]="Linode|https://status.linode.com/api/v2/status.json|statuspage|󰇅"

    # Development Tools
    ["github"]="GitHub|https://www.githubstatus.com/api/v2/status.json|statuspage|󰊤"
    ["gitlab"]="GitLab|https://status.gitlab.com/|gitlab_scrape|󰮠"

    # Monitoring & Analytics
    ["datadog"]="DD|https://status.datadoghq.com/api/v2/status.json|statuspage|🐕"

    # Communication
    ["discord"]="Discord|https://discordstatus.com/api/v2/status.json|statuspage|󰙯"

    # Major International Cloud Providers
    ["ibm"]="IBM|https://statuspage.ibmcloudsecurity.com/api/v2/status.json|statuspage|🔵"
    ["oracle"]="Oracle|https://ocloudinfra.statuspage.io/api/v2/status.json|statuspage|🔴"
)

# =============================================================================
# Status Parsing Functions
# =============================================================================

# Fetch API with timeout and error handling
fetch_api() {
    local url="$1"
    local timeout
    timeout=$(get_cached_option "@powerkit_plugin_cloudstatus_timeout" "$POWERKIT_PLUGIN_CLOUDSTATUS_TIMEOUT")

    curl -sf -m "$timeout" -H "User-Agent: tmux-powerkit/1.0" "$url" 2>/dev/null
}

# Parse StatusPage.io API (most common)
parse_statuspage() {
    local data="$1"
    local indicator

    if command -v jq &>/dev/null; then
        indicator=$(echo "$data" | jq -r '.status.indicator // empty' 2>/dev/null)
    else
        indicator=$(echo "$data" | grep -o '"indicator":"[^"]*"' | head -1 | cut -d'"' -f4)
    fi

    [[ -z "$indicator" ]] && indicator="unknown"
    echo "$indicator"
}

# Parse GCP incidents API
parse_gcp() {
    local data="$1"

    if command -v jq &>/dev/null; then
        local active_incidents
        active_incidents=$(echo "$data" | jq '[.[] | select(.end == null)] | length' 2>/dev/null)
        [[ "$active_incidents" -gt 0 ]] && echo "major" || echo "operational"
    else
        # Fallback: check for active incidents (no end time)
        if echo "$data" | grep -q '"end":null'; then
            echo "major"
        elif [[ "$data" == "[]" || -z "$data" ]]; then
            echo "operational"
        else
            echo "minor"
        fi
    fi
}

# Parse Heroku specific API
parse_heroku() {
    local data="$1"
    local status

    if command -v jq &>/dev/null; then
        status=$(echo "$data" | jq -r '.status // empty' 2>/dev/null)
    else
        status=$(echo "$data" | grep -o '"status":"[^"]*"' | head -1 | cut -d'"' -f4)
    fi

    case "$status" in
        green|production) echo "operational" ;;
        yellow|development) echo "minor" ;;
        orange|maintenance) echo "major" ;;
        red|critical) echo "critical" ;;
        *) echo "operational" ;;
    esac
}

# Parse AWS RSS feed
parse_aws_rss() {
    local data="$1"

    # Check if RSS feed contains recent incidents (entries in last 24 hours indicate issues)
    if echo "$data" | grep -q "<item>" && echo "$data" | grep -q "<title>" && echo "$data" | grep -q "<description>"; then
        # If there are recent entries, check if they indicate resolved issues
        if echo "$data" | grep -qi "resolved\|resolved\|completed"; then
            echo "operational"
        else
            echo "minor"
        fi
    else
        # No recent incidents
        echo "operational"
    fi
}

# Parse Azure RSS feed
parse_azure_rss() {
    local data="$1"

    # Azure RSS feed contains incidents when there are issues
    if echo "$data" | grep -q "<item>" && echo "$data" | grep -q "<title>"; then
        # Check severity in titles/descriptions
        if echo "$data" | grep -qi "critical\|major\|outage"; then
            echo "major"
        elif echo "$data" | grep -qi "degraded\|minor\|issue"; then
            echo "minor"
        else
            echo "operational"
        fi
    else
        # No incidents
        echo "operational"
    fi
}

# Parse GitLab by scraping (fallback method)
parse_gitlab_scrape() {
    local data="$1"

    # Look for status indicators in the HTML
    if echo "$data" | grep -qi "All Systems Operational"; then
        echo "operational"
    elif echo "$data" | grep -qi "Operational" && ! echo "$data" | grep -qi "Degraded\|Outage\|Incident"; then
        echo "operational"
    elif echo "$data" | grep -qi "Degraded\|Minor"; then
        echo "minor"
    elif echo "$data" | grep -qi "Outage\|Major\|Critical"; then
        echo "major"
    else
        echo "unknown"
    fi
}

# Get provider status
get_provider_status() {
    local provider_key="$1"
    local provider_config="${CLOUD_PROVIDERS[$provider_key]}"

    [[ -z "$provider_config" ]] && return 1

    IFS='|' read -r name api_url parser_type icon <<< "$provider_config"

    local data indicator
    data=$(fetch_api "$api_url")

    if [[ -z "$data" ]]; then
        echo "unknown"
        return
    fi

    case "$parser_type" in
        statuspage) indicator=$(parse_statuspage "$data") ;;
        gcp) indicator=$(parse_gcp "$data") ;;
        heroku) indicator=$(parse_heroku "$data") ;;
        aws_rss) indicator=$(parse_aws_rss "$data") ;;
        azure_rss) indicator=$(parse_azure_rss "$data") ;;
        gitlab_scrape) indicator=$(parse_gitlab_scrape "$data") ;;
        *) indicator="unknown" ;;
    esac

    echo "$indicator"
}

# Normalize status indicators
normalize_indicator() {
    local indicator="$1"

    # Convert all status indicators to normalized format
    case "$indicator" in
        # Operational states
        none|operational|green|ok|normal|available|up) echo "operational" ;;

        # Minor issues
        minor|degraded_performance|degraded|yellow|warning|development|partial) echo "minor" ;;

        # Maintenance (treated as minor)
        maintenance|scheduled|planned) echo "maintenance" ;;

        # Major issues
        major|partial_outage|orange|outage|down|disruption|service_disruption) echo "major" ;;

        # Critical issues
        critical|major_outage|red|emergency|severe) echo "critical" ;;

        # Unknown
        *) echo "unknown" ;;
    esac
}

# Get severity level from normalized indicator
get_severity_level() {
    local indicator="$1"
    local normalized
    normalized=$(normalize_indicator "$indicator")

    case "$normalized" in
        operational) echo "0" ;;
        minor|maintenance) echo "1" ;;
        major) echo "2" ;;
        critical) echo "3" ;;
        *) echo "9" ;; # unknown
    esac
}

# Get severity symbol
get_severity_symbol() {
    local indicator="$1"
    local normalized symbol_set
    normalized=$(normalize_indicator "$indicator")
    symbol_set=$(get_cached_option "@powerkit_plugin_cloudstatus_symbols" "$POWERKIT_PLUGIN_CLOUDSTATUS_SYMBOLS")

    case "$symbol_set" in
        emoji)
            case "$normalized" in
                operational) echo "✅" ;;
                minor) echo "⚠️" ;;
                maintenance) echo "🔧" ;;
                major) echo "🟡" ;;
                critical) echo "🔴" ;;
                *) echo "❓" ;;
            esac
            ;;
        simple|*)
            case "$normalized" in
                operational) echo "✓" ;;
                minor) echo "⚠" ;;
                maintenance) echo "🔧" ;;
                major) echo "⚠⚠" ;;
                critical) echo "✗" ;;
                *) echo "?" ;;
            esac
            ;;
    esac
}

# Get provider icon
get_provider_icon() {
    local provider_key="$1"
    local provider_config="${CLOUD_PROVIDERS[$provider_key]}"

    [[ -z "$provider_config" ]] && return

    IFS='|' read -r name api_url parser_type icon <<< "$provider_config"
    echo "$icon"
}

# Get provider display name
get_provider_name() {
    local provider_key="$1"
    local provider_config="${CLOUD_PROVIDERS[$provider_key]}"

    [[ -z "$provider_config" ]] && return

    IFS='|' read -r name api_url parser_type icon <<< "$provider_config"
    echo "$name"
}

plugin_get_display_info() {
    local content="${1:-}"
    
    # Hide if no content
    [[ -z "$content" ]] && { build_display_info "0" "" "" ""; return; }
    
    local accent="" accent_icon=""
    local cached_data max_severity=0
    
    # Analyze cached data to determine severity
    if cached_data=$(cache_get "$CACHE_KEY" "$CACHE_TTL"); then
        while IFS='|' read -r provider indicator; do
            [[ -z "$provider" || -z "$indicator" ]] && continue
            local severity
            severity=$(get_severity_level "$indicator")
            [[ "$severity" -gt "$max_severity" && "$severity" -lt 9 ]] && max_severity="$severity"
        done <<< "$cached_data"
    fi
    
    # Set colors based on max severity
    case "$max_severity" in
        1) # minor
            accent=$(get_cached_option "@powerkit_plugin_cloudstatus_warning_accent_color" "$POWERKIT_PLUGIN_CLOUDSTATUS_WARNING_ACCENT_COLOR")
            accent_icon=$(get_cached_option "@powerkit_plugin_cloudstatus_warning_accent_color_icon" "$POWERKIT_PLUGIN_CLOUDSTATUS_WARNING_ACCENT_COLOR_ICON")
            ;;
        2|3) # major/critical
            accent=$(get_cached_option "@powerkit_plugin_cloudstatus_critical_accent_color" "$POWERKIT_PLUGIN_CLOUDSTATUS_CRITICAL_ACCENT_COLOR")
            accent_icon=$(get_cached_option "@powerkit_plugin_cloudstatus_critical_accent_color_icon" "$POWERKIT_PLUGIN_CLOUDSTATUS_CRITICAL_ACCENT_COLOR_ICON")
            ;;
    esac
    
    build_display_info "1" "$accent" "$accent_icon" ""
}

load_plugin() {
    local providers format separator issues_only
    providers=$(get_cached_option "@powerkit_plugin_cloudstatus_providers" "$POWERKIT_PLUGIN_CLOUDSTATUS_PROVIDERS")
    format=$(get_cached_option "@powerkit_plugin_cloudstatus_format" "$POWERKIT_PLUGIN_CLOUDSTATUS_FORMAT")
    separator=$(get_cached_option "@powerkit_plugin_cloudstatus_separator" "$POWERKIT_PLUGIN_CLOUDSTATUS_SEPARATOR")
    issues_only=$(get_cached_option "@powerkit_plugin_cloudstatus_issues_only" "$POWERKIT_PLUGIN_CLOUDSTATUS_ISSUES_ONLY")

    [[ -z "$providers" ]] && return 0

    # Check cache first
    local cached
    if cached=$(cache_get "$CACHE_KEY" "$CACHE_TTL"); then
        format_output "$cached" "$format" "$separator"
        return 0
    fi

    # Parse provider list
    IFS=',' read -ra provider_list <<< "$providers"
    local results=()

    for provider in "${provider_list[@]}"; do
        provider=$(echo "$provider" | xargs) # trim whitespace
        [[ -z "$provider" ]] && continue

        # Check if provider exists
        if [[ -n "${CLOUD_PROVIDERS[$provider]}" ]]; then
            local status
            status=$(get_provider_status "$provider")
            results+=("$provider|$status")
        fi
    done

    # Cache results
    local cache_data
    cache_data=$(printf '%s\n' "${results[@]}")
    cache_set "$CACHE_KEY" "$cache_data"

    format_output "$cache_data" "$format" "$separator"
}

format_output() {
    local data="$1" format="$2" separator="$3"
    [[ -z "$data" ]] && return
    
    local output_parts=()
    local issues_only
    issues_only=$(get_cached_option "@powerkit_plugin_cloudstatus_issues_only" "$POWERKIT_PLUGIN_CLOUDSTATUS_ISSUES_ONLY")

    while IFS='|' read -r provider indicator; do
        [[ -z "$provider" || -z "$indicator" ]] && continue

        local severity_level
        severity_level=$(get_severity_level "$indicator")
        
        # Skip operational (severity 0) if issues_only
        [[ "$issues_only" == "true" && "$severity_level" == "0" ]] && continue

        local name icon symbol formatted_part
        name=$(get_provider_name "$provider")
        icon=$(get_provider_icon "$provider")
        
        # Only show symbols if not in issues_only mode
        if [[ "$issues_only" == "true" ]]; then
            symbol=""
        else
            symbol=$(get_severity_symbol "$indicator")
        fi

        case "$format" in
            icon_only)
                if [[ "$issues_only" == "true" ]]; then
                    formatted_part="$icon"
                else
                    formatted_part="$symbol"
                fi
                ;;
            name_only)
                formatted_part="$name"
                ;;
            name_symbol)
                formatted_part="${name}${symbol}"
                ;;
            *)
                formatted_part="${icon}${symbol}"
                ;;
        esac

        [[ -n "$formatted_part" ]] && output_parts+=("$formatted_part")
    done <<< "$data"

    [[ ${#output_parts[@]} -eq 0 ]] && return
    
    local IFS="$separator"
    printf '%s' "${output_parts[*]}"
}

[[ "${BASH_SOURCE[0]}" == "${0}" ]] && load_plugin || true
