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

**`src/theme.sh`** (142 lines)
- Main orchestration script that configures tmux appearance
- Loads the selected color palette from `src/palletes/`
- Configures status bar, window styles, borders, and pane styles
- Dynamically loads and executes plugins from `src/plugin/`
- Handles plugin rendering with proper separators and colors (e.g., datetime plugin uses static rendering)

**`src/utils.sh`** (76 lines)
- `get_tmux_option()` - Retrieves tmux options with fallback defaults
- `generate_left_side_string()` - Creates left status bar (session info)
- `generate_inactive_window_string()` - Creates inactive window formatting
- `generate_active_window_string()` - Creates active window formatting
- Handles both transparent and non-transparent status bar modes

**`src/cache.sh`** - Caching System
- `cache_init()` - Ensures cache directory exists
- `cache_get(plugin_name, ttl)` - Returns cached value if valid (not expired)
- `cache_set(plugin_name, value)` - Stores value in cache file
- `cache_is_valid(plugin_name, ttl)` - Checks if cache is still valid
- `cache_invalidate(plugin_name)` - Removes cache for a specific plugin
- `cache_clear_all()` - Clears all cached data
- `cache_remaining_ttl(plugin_name, ttl)` - Returns remaining seconds until expiry
- Cache files stored in `$XDG_CACHE_HOME/tmux-tokyo-night/` (or `~/.cache/tmux-tokyo-night/`)

### Color Palettes

Located in `src/palletes/*.sh` (night.sh, storm.sh, moon.sh, day.sh)
- Each defines a bash associative array `PALLETE` with color keys
- Colors reference Tokyo Night theme specifications
- Exported globally for use by theme.sh and plugins

### Plugin System

**Plugin Architecture:**
1. Each plugin in `src/plugin/*.sh` exports variables: `plugin_<name>_icon`, `plugin_<name>_accent_color`, `plugin_<name>_accent_color_icon`
2. `theme.sh` iterates through enabled plugins (from `@theme_plugins` option)
3. For most plugins: Output is generated dynamically via `#($plugin_script_path)` in tmux status bar
4. For datetime: Output is pre-rendered at theme load time
5. For battery: Uses the standard plugin format with caching; does not accept arguments or use templates/placeholders.

**Available Plugins:**

- `datetime.sh` - Shows date/time using tmux `strftime` format
- `weather.sh` - Fetches weather from wttr.in API (supports caching, TTL configurable via `@theme_plugin_weather_cache_ttl`)
- `battery.sh` - Shows battery status with color-coded levels (red/yellow/green thresholds)
- `playerctl.sh` - Media player info via MPRIS (Linux only, cached with configurable TTL)
- `spt.sh` - Spotify integration via spotify-tui (cached with configurable TTL)
- `homebrew.sh` - Homebrew outdated packages count (cached, default 30 min TTL)
- `yay.sh` - AUR helper updates (cached, default 30 min TTL)

**Plugin Cache Configuration:**

Each cacheable plugin supports a TTL (Time To Live) option:
- `@theme_plugin_weather_cache_ttl` - Weather cache TTL in seconds (default: 900 = 15 min)
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
- **Dynamic plugins** (weather, playerctl, etc.): Executed by tmux on each status refresh via `#(command)` syntax
- **Template plugins** (battery): Template created at load time, script fills in dynamic values including colors

### Separator System
- Left separator: Used for session/windows (flows left to right)
- Right separator: Used for plugins (flows right to left)
- Each plugin gets: icon separator → icon → content separator → content → end separator
- Last plugin omits the end separator

## Adding New Plugins

1. Create `src/plugin/<name>.sh`
2. Export three variables: `plugin_<name>_icon`, `plugin_<name>_accent_color`, `plugin_<name>_accent_color_icon`
3. Implement plugin logic that outputs the desired status text
4. Add plugin name to `@theme_plugins` option in documentation
5. Plugin will be automatically discovered and loaded by `theme.sh`

## Important Notes

- All shell scripts use `#!/usr/bin/env bash` and should be POSIX-compatible where possible
- Color values from palette must be referenced as `${PALLETE[key]}`
- Tmux options are read via `get_tmux_option` helper with fallback defaults
- The `set -euxo pipefail` in theme.sh ensures strict error handling
- Weather plugin: `jq` is optional. It is only required for auto-location detection via IP; if you provide a location via `@theme_plugin_weather_location`, the plugin works without `jq`.
- Battery plugin contains code adapted from tmux-plugins/tmux-battery (MIT licensed)
