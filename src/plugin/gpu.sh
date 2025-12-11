#!/usr/bin/env bash
# =============================================================================
# Plugin: gpu
# Description: Display GPU usage and memory (NVIDIA, AMD, Intel, Apple Silicon)
# Dependencies: nvidia-smi (NVIDIA), rocm-smi (AMD), intel_gpu_top (Intel)
# =============================================================================

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$ROOT_DIR/../plugin_bootstrap.sh"

plugin_init "gpu"

# =============================================================================
# GPU Detection & Info Functions
# =============================================================================

# Detect available GPU and return type
detect_gpu() {
    # NVIDIA (most common for monitoring)
    command -v nvidia-smi &>/dev/null && { echo "nvidia"; return 0; }

    # AMD ROCm
    command -v rocm-smi &>/dev/null && { echo "amd"; return 0; }

    # Intel (Linux)
    command -v intel_gpu_top &>/dev/null && { echo "intel"; return 0; }

    # Apple Silicon - no user-accessible GPU metrics without sudo
    # Skip detection on macOS as we can't provide useful data

    return 1
}

# NVIDIA GPU via nvidia-smi
get_nvidia() {
    local show_mem="$1"
    local query="utilization.gpu"
    [[ "$show_mem" == "true" ]] && query+=",memory.used,memory.total"

    local result
    result=$(nvidia-smi --query-gpu="$query" --format=csv,noheader,nounits 2>/dev/null | head -1)
    [[ -z "$result" ]] && return 1

    if [[ "$show_mem" == "true" ]]; then
        local gpu_pct mem_used mem_total
        IFS=', ' read -r gpu_pct mem_used mem_total <<< "$result"
        # Convert to GB if > 1024 MB using POWERKIT_BYTE_KB constant
        if [[ "$mem_total" -gt "$POWERKIT_BYTE_KB" ]]; then
            # Use bash arithmetic for division (multiply by 10 for one decimal place)
            local mem_used_gb=$((mem_used * 10 / POWERKIT_BYTE_KB))
            local mem_total_gb=$((mem_total * 10 / POWERKIT_BYTE_KB))
            printf '%d%% %d.%d/%d.%dG' "$gpu_pct" $((mem_used_gb/10)) $((mem_used_gb%10)) $((mem_total_gb/10)) $((mem_total_gb%10))
        else
            printf '%d%% %d/%dM' "$gpu_pct" "$mem_used" "$mem_total"
        fi
    else
        printf '%d%%' "$result"
    fi
}

# AMD GPU via rocm-smi
get_amd() {
    local show_mem="$1"
    local gpu_pct mem_pct

    # GPU utilization
    gpu_pct=$(rocm-smi --showuse 2>/dev/null | awk '/GPU use/ {gsub(/%/,"",$NF); print $NF; exit}')
    [[ -z "$gpu_pct" ]] && return 1

    if [[ "$show_mem" == "true" ]]; then
        mem_pct=$(rocm-smi --showmemuse 2>/dev/null | awk '/GPU memory use/ {gsub(/%/,"",$NF); print $NF; exit}')
        printf '%d%% M:%d%%' "$gpu_pct" "${mem_pct:-0}"
    else
        printf '%d%%' "$gpu_pct"
    fi
}

# Intel GPU via intel_gpu_top (requires root or video group)
get_intel() {
    local gpu_pct
    # intel_gpu_top outputs JSON with -J, sample for 1 second
    gpu_pct=$(timeout 1 intel_gpu_top -J -s 500 2>/dev/null | \
        awk -F'"' '/"busy":/ {gsub(/[^0-9.]/,"",$4); printf "%.0f", $4; exit}')

    [[ -z "$gpu_pct" ]] && return 1
    printf '%d%%' "$gpu_pct"
}

# =============================================================================
# Plugin Interface
# =============================================================================

plugin_get_type() { printf 'conditional'; }

plugin_get_display_info() {
    local content="$1"
    local show="1" accent="" accent_icon="" icon=""

    [[ -z "$content" || "$content" == "N/A" ]] && { build_display_info "0" "" "" ""; return; }

    # Detect GPU type to select appropriate icon
    local gpu_type
    gpu_type=$(detect_gpu)

    case "$gpu_type" in
        nvidia) icon=$(get_cached_option "@powerkit_plugin_gpu_icon_nvidia" "$POWERKIT_PLUGIN_GPU_ICON_NVIDIA") ;;
        amd)    icon=$(get_cached_option "@powerkit_plugin_gpu_icon_amd" "$POWERKIT_PLUGIN_GPU_ICON_AMD") ;;
        intel)  icon=$(get_cached_option "@powerkit_plugin_gpu_icon_intel" "$POWERKIT_PLUGIN_GPU_ICON_INTEL") ;;
        apple)  icon=$(get_cached_option "@powerkit_plugin_gpu_icon_apple" "$POWERKIT_PLUGIN_GPU_ICON_APPLE") ;;
        *)      icon=$(get_cached_option "@powerkit_plugin_gpu_icon" "$POWERKIT_PLUGIN_GPU_ICON") ;;
    esac

    # Extract percentage for threshold checking
    local pct
    pct=$(echo "$content" | grep -oE '^[0-9]+' | head -1)

    if [[ -n "$pct" ]]; then
        local warn_thresh crit_thresh
        warn_thresh=$(get_cached_option "@powerkit_plugin_gpu_warning_threshold" "$POWERKIT_PLUGIN_GPU_WARNING_THRESHOLD")
        crit_thresh=$(get_cached_option "@powerkit_plugin_gpu_critical_threshold" "$POWERKIT_PLUGIN_GPU_CRITICAL_THRESHOLD")

        if [[ "$pct" -ge "$crit_thresh" ]]; then
            accent=$(get_cached_option "@powerkit_plugin_gpu_critical_accent_color" "$POWERKIT_PLUGIN_GPU_CRITICAL_ACCENT_COLOR")
            accent_icon=$(get_cached_option "@powerkit_plugin_gpu_critical_accent_color_icon" "$POWERKIT_PLUGIN_GPU_CRITICAL_ACCENT_COLOR_ICON")
        elif [[ "$pct" -ge "$warn_thresh" ]]; then
            accent=$(get_cached_option "@powerkit_plugin_gpu_warning_accent_color" "$POWERKIT_PLUGIN_GPU_WARNING_ACCENT_COLOR")
            accent_icon=$(get_cached_option "@powerkit_plugin_gpu_warning_accent_color_icon" "$POWERKIT_PLUGIN_GPU_WARNING_ACCENT_COLOR_ICON")
        fi
    fi

    build_display_info "$show" "$accent" "$accent_icon" "$icon"
}

# =============================================================================
# Main
# =============================================================================

load_plugin() {
    local cached
    if cached=$(cache_get "$CACHE_KEY" "$CACHE_TTL"); then
        printf '%s' "$cached"
        return 0
    fi

    local gpu_type result
    gpu_type=$(detect_gpu) || return 0

    local show_mem
    show_mem=$(get_cached_option "@powerkit_plugin_gpu_show_memory" "$POWERKIT_PLUGIN_GPU_SHOW_MEMORY")

    case "$gpu_type" in
        nvidia) result=$(get_nvidia "$show_mem") ;;
        amd)    result=$(get_amd "$show_mem") ;;
        intel)  result=$(get_intel) ;;
        apple)  result=$(get_apple) ;;
        *)      return 0 ;;
    esac

    [[ -z "$result" ]] && return 0

    cache_set "$CACHE_KEY" "$result"
    printf '%s' "$result"
}

[[ "${BASH_SOURCE[0]}" == "${0}" ]] && load_plugin || true
