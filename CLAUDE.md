# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Tokyo Night Tmux Theme is a tmux plugin that applies Tokyo Night color schemes to tmux status bars. It's distributed through TPM (Tmux Plugin Manager) and supports multiple theme variations (night, storm, moon, day) with customizable plugins for displaying system information.

## Development Commands

### Linting

```bash
# Run shellcheck on all shell scripts
shellcheck src/**/*.sh src/*.sh tmux-tokyo-night.tmux
```

Note: The project uses GitHub Actions to run shellcheck automatically on push/PR (see `.github/workflows/shellcheck.yml`).

### Testing

Manual testing is required:

1. Install the plugin via TPM in a test tmux configuration
2. Source the plugin: `tmux source ~/.tmux.conf`
3. Verify visual appearance and plugin functionality
4. Test different theme variations and plugin combinations

## Architecture

### Entry Point

- `tmux-tokyo-night.tmux` - Main entry point called by TPM, immediately delegates to `src/theme.sh`

### Core Components

**`src/defaults.sh`** - Centralized Default Values

- Contains ALL default values for the theme in one place
- Modify this file to change defaults across the entire theme
- Uses source guard (`_DEFAULTS_LOADED`) to prevent multiple sourcing
- Provides `get_plugin_default()` helper function
- Variables follow naming convention: `PLUGIN_<NAME>_<OPTION>` (e.g., `PLUGIN_BATTERY_ICON`)
- Theme core options: `THEME_DEFAULT_VARIATION`, `THEME_DEFAULT_PLUGINS`, etc.

**`src/theme.sh`** (142 lines)

- Main orchestration script that configures tmux appearance
- Sources `defaults.sh` first for centralized default values
- Loads the selected color palette from `src/palletes/`
- Configures status bar, window styles, borders, and pane styles
- Dynamically loads and executes plugins from `src/plugin/`
- Handles plugin rendering with proper separators and colors (e.g., datetime plugin uses static rendering)
- Sources plugins once and calls `load_plugin()` function to avoid double execution

**`src/utils.sh`** (76 lines)

- `get_tmux_option()` - Retrieves tmux options with fallback defaults
- `get_os()` - Returns cached OS name (avoids repeated `uname` calls)
- `is_macos()` / `is_linux()` - Convenience functions for OS detection
- `generate_left_side_string()` - Creates left status bar (session info)
- `generate_inactive_window_string()` - Creates inactive window formatting
- `generate_active_window_string()` - Creates active window formatting
- Handles both transparent and non-transparent status bar modes
- Uses source guard to prevent multiple sourcing

**`src/cache.sh`** - Caching System

- `cache_init()` - Ensures cache directory exists (runs only once per session)
- `cache_get(plugin_name, ttl)` - Returns cached value if valid (not expired)
- `cache_set(plugin_name, value)` - Stores value in cache file
- `cache_is_valid(plugin_name, ttl)` - Checks if cache is still valid
- `cache_invalidate(plugin_name)` - Removes cache for a specific plugin
- `cache_clear_all()` - Clears all cached data
- `cache_remaining_ttl(plugin_name, ttl)` - Returns remaining seconds until expiry
- Cache files stored in `$XDG_CACHE_HOME/tmux-tokyo-night/` (or `~/.cache/tmux-tokyo-night/`)
- Uses source guard to prevent multiple sourcing

### Color Palettes

Located in `src/palletes/*.sh` (night.sh, storm.sh, moon.sh, day.sh)

- Each defines a bash associative array `PALLETE` with color keys
- Colors reference Tokyo Night theme specifications
- Exported globally for use by theme.sh and plugins

### Plugin System

**Plugin Architecture:**

1. Each plugin in `src/plugin/*.sh` exports variables: `plugin_<name>_icon`, `plugin_<name>_accent_color`, `plugin_<name>_accent_color_icon`
2. `theme.sh` iterates through enabled plugins (from `@theme_plugins` option)
3. Plugins are rendered using wrapper scripts based on their features:
   - **conditional_plugin.sh**: For plugins that may or may not produce output (git, kubernetes, spotify, homebrew, yay)
   - **threshold_plugin.sh**: For plugins with display_threshold or threshold_mode (battery, cpu, memory, disk, loadavg)
   - **static_plugin.sh**: For static plugins followed by conditional plugins (network, weather, etc.)
   - Direct rendering: For simple plugins or when no special handling is needed
4. For datetime: Output is pre-rendered at theme load time using tmux's strftime

**Available Plugins:**

System Monitoring:

- `cpu.sh` - Shows CPU usage percentage (uses ps on macOS, /proc/stat on Linux)
- `memory.sh` - Shows memory usage (percent or used/total format)
- `loadavg.sh` - Shows system load average (1, 5, 15 min or all)
- `disk.sh` - Shows disk usage for configurable mount point
- `network.sh` - Shows network download/upload speeds
- `uptime.sh` - Shows system uptime

Development:

- `git.sh` - Shows git branch and status (conditional - only in git repos)

- `kubernetes.sh` - Shows current k8s context/namespace

Information:

- `datetime.sh` - Shows date/time using tmux `strftime` format
- `hostname.sh` - Shows system hostname
- `weather.sh` - Fetches weather from wttr.in API

Media:

- `playerctl.sh` - Media player info via MPRIS (Linux only)
- `spt.sh` - Spotify integration via spotify-tui

Package Managers:

- `homebrew.sh` - Homebrew outdated packages count (macOS)
- `yay.sh` - AUR helper updates (Arch Linux)
- `battery.sh` - Shows battery status with color-coded levels

**Plugin Cache Configuration:**

All cacheable plugins support a TTL (Time To Live) option:

- `@theme_plugin_cpu_cache_ttl` - CPU cache TTL in seconds (default: 2)
- `@theme_plugin_memory_cache_ttl` - Memory cache TTL in seconds (default: 5)
- `@theme_plugin_loadavg_cache_ttl` - Load average cache TTL in seconds (default: 5)
- `@theme_plugin_disk_cache_ttl` - Disk cache TTL in seconds (default: 60)
- `@theme_plugin_network_cache_ttl` - Network cache TTL in seconds (default: 5)
- `@theme_plugin_uptime_cache_ttl` - Uptime cache TTL in seconds (default: 60)
- `@theme_plugin_git_cache_ttl` - Git cache TTL in seconds (default: 5)

- `@theme_plugin_kubernetes_cache_ttl` - Kubernetes cache TTL in seconds (default: 30)
- `@theme_plugin_weather_cache_ttl` - Weather cache TTL in seconds (default: 900 = 15 min)
- `@theme_plugin_battery_cache_ttl` - Battery cache TTL in seconds (default: 30)
- `@theme_plugin_playerctl_cache_ttl` - Playerctl cache TTL in seconds (default: 5)
- `@theme_plugin_spt_cache_ttl` - Spotify TUI cache TTL in seconds (default: 5)
- `@theme_plugin_homebrew_cache_ttl` - Homebrew cache TTL in seconds (default: 1800 = 30 min)
- `@theme_plugin_yay_cache_ttl` - Yay cache TTL in seconds (default: 1800 = 30 min)

### Configuration Flow

1. User sets `@theme_*` options in `.tmux.conf`
2. TPM loads `tmux-tokyo-night.tmux` which calls `src/theme.sh`
3. `theme.sh` loads selected palette and user options
4. Status bar strings are generated with proper separators and colors
5. Enabled plugins are loaded and rendered in the status bar

## Key Implementation Details

### Transparency Support

- When `@theme_transparent_status_bar` is `true`, background colors use `default` instead of palette colors
- Requires separate inverse separator characters for proper visual appearance

### Plugin Rendering Strategy

- **Static plugins** (datetime): Executed once at theme load, output embedded in status string
- **Dynamic plugins** (weather, network, etc.): Executed by tmux on each status refresh via wrapper scripts
- **Conditional plugins** (git, kubernetes, homebrew, yay, spotify): Only render when they have output
- **Threshold plugins** (battery, cpu, memory, disk, loadavg): Support conditional display and dynamic colors based on values

### Plugin Rendering Wrappers

**`src/conditional_plugin.sh`**

- Wraps plugins that may produce empty output (git, kubernetes, etc.)
- Only renders the segment if the plugin outputs content
- Dynamically determines if it's the last visible plugin by checking subsequent plugins
- Arguments: plugin_name, accent_color, accent_color_icon, plugin_icon, white_color, bg_highlight, transparent, prev_accent, plugins_after

**`src/static_plugin.sh`**

- Wraps static plugins (always produce output) that are followed by conditional plugins
- Checks if any following conditional plugins have content to determine if it's the last visible
- Uses `any_plugin_has_content()` to check subsequent plugins at runtime
- Arguments: plugin_name, accent_color, accent_color_icon, plugin_icon, white_color, bg_highlight, transparent, plugins_after

**`src/threshold_plugin.sh`**

- Wraps plugins with display threshold or dynamic color support
- Features:
  1. Conditional display based on value threshold (display_threshold + display_condition)
  2. Dynamic colors based on 3-level thresholds (threshold_mode: ascending/descending)
  3. Simple low threshold with custom icon (low_threshold + icon_low + low_accent_color)
- Supports serialized palette for color resolution

### Separator System

- Left separator: Used for session/windows (flows left to right)
- Right separator: Used for plugins (flows right to left)
- Each plugin gets: icon separator → icon → content separator → content → end separator
- Last plugin omits the end separator AND the trailing space
- Separator characters (RIGHT_SEPARATOR, RIGHT_SEPARATOR_INVERSE) are stored in tmux options

## Adding New Plugins

1. Create `src/plugin/<name>.sh`
2. Source `utils.sh` and `cache.sh` from `$ROOT_DIR/../`
3. Export three variables: `plugin_<name>_icon`, `plugin_<name>_accent_color`, `plugin_<name>_accent_color_icon`
4. Define a `load_plugin()` function that outputs the desired status text
5. Add execution guard at end: `if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then load_plugin; fi`
6. Use caching for expensive operations with `cache_get`/`cache_set`
7. Use `is_macos()`/`is_linux()` for OS-specific logic instead of calling `uname`
8. Add plugin name to `@theme_plugins` option in documentation
9. Plugin will be automatically discovered and loaded by `theme.sh`

## Performance Optimizations

- **Source guards**: `utils.sh` and `cache.sh` use guards to prevent multiple parsing
- **Cached OS detection**: `_CACHED_OS` variable set once, used by `is_macos()`/`is_linux()`
- **Single plugin execution**: `theme.sh` sources plugins once and calls `load_plugin()`
- **File-based caching**: Plugins cache results to reduce expensive operations
- **Optimized commands**: e.g., CPU on macOS uses `ps` instead of slow `top -l 1`

## Important Notes

- All shell scripts use `#!/usr/bin/env bash` and should be POSIX-compatible where possible
- Color values from palette must be referenced as `${PALLETE[key]}`
- Tmux options are read via `get_tmux_option` helper with fallback defaults
- The `set -euxo pipefail` in theme.sh ensures strict error handling
- Weather plugin: `jq` is optional. It is only required for auto-location detection via IP; if you provide a location via `@theme_plugin_weather_location`, the plugin works without `jq`.
- Battery plugin contains code adapted from tmux-plugins/tmux-battery (MIT licensed)
