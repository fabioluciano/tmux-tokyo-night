<div align="center">
  <h1>🌃 Tokyo Night Tmux Theme</h1>
  
  <h4>A clean, elegant tmux theme inspired by the popular Tokyo Night color scheme</h4>
  
  <p>
    <a href="#features"><img src="https://img.shields.io/badge/Features-blue?style=flat-square" alt="Features"></a>
    <a href="#screenshots"><img src="https://img.shields.io/badge/Screenshots-purple?style=flat-square" alt="Screenshots"></a>
    <a href="#installation"><img src="https://img.shields.io/badge/Install-green?style=flat-square" alt="Install"></a>
    <a href="#configuration"><img src="https://img.shields.io/badge/Config-orange?style=flat-square" alt="Configuration"></a>
    <a href="#plugins"><img src="https://img.shields.io/badge/Plugins-red?style=flat-square" alt="Plugins"></a>
  </p>

  > ⚠️ **Version 2.0 - Breaking Changes**: This release includes significant refactoring with improved plugin architecture and caching system. See [Migration Guide](#migration-from-v1) below.
    
  ---
</div>

## ✨ Features

- 🎨 **Multiple color variations**: Night, Storm, Moon, and Day
- 🔌 **18 built-in plugins** for system monitoring and information display
- 🪟 **Transparency support** with customizable separators
- 📊 **Double bar layout** option for separating windows and plugins
- ⚡ **Smart caching system** for improved performance (configurable TTL per plugin)
- 🚀 **Optimized performance** with cached OS detection and source guards
- 🔧 **Highly customizable** with per-plugin configuration options
- 🎯 **Conditional plugins** (git, docker, homebrew, yay, spotify) that only appear when relevant
- 🌈 **Dynamic threshold colors** - plugins change colors based on values (e.g., battery turns red when low)
- 👁️ **Conditional display** - show plugins only when values meet threshold conditions
- 🎵 **Cross-platform Spotify** - unified plugin supporting macOS (shpotify, osascript), Linux (playerctl), and spt

## 📸 Screenshots

### Tokyo Night - Default Variation

| Inactive | Active |
|----------|--------|
| ![Tokyo Night Inactive](./assets/tokyo-night.png) | ![Tokyo Night Active](./assets/tokyo-night-active.png) |

## 📦 Installation

### Using TPM (recommended)

Add the plugin to your `~/.tmux.conf`:

```bash
set -g @plugin 'fabioluciano/tmux-tokyo-night'
```

Press <kbd>prefix</kbd> + <kbd>I</kbd> to install.

### Manual Installation

```bash
git clone https://github.com/fabioluciano/tmux-tokyo-night.git ~/.tmux/plugins/tmux-tokyo-night
```

Add to your `~/.tmux.conf`:

```bash
run-shell ~/.tmux/plugins/tmux-tokyo-night/tmux-tokyo-night.tmux
```

## ⚙️ Configuration

### Theme Options

| Option | Description | Values | Default |
|--------|-------------|--------|---------|
| `@theme_variation` | Color scheme variation | `night`, `storm`, `moon`, `day` | `night` |
| `@theme_plugins` | Comma-separated list of plugins to enable | See [Plugins](#plugins) | `datetime,weather` |
| `@theme_disable_plugins` | Disable all plugins | `0`, `1` | `0` |
| `@theme_bar_layout` | Status bar layout mode | `single`, `double` | `single` |
| `@theme_transparent_status_bar` | Enable transparency | `true`, `false` | `false` |

### Appearance Options

| Option | Description | Default |
|--------|-------------|---------|
| `@theme_active_pane_border_style` | Active pane border color | `#737aa2` |
| `@theme_inactive_pane_border_style` | Inactive pane border color | `#292e42` |
| `@theme_left_separator` | Left powerline separator | `` |
| `@theme_right_separator` | Right powerline separator | `` |
| `@theme_window_with_activity_style` | Style for windows with activity | `italics` |
| `@theme_status_bell_style` | Style for bell alerts | `bold` |

### Transparency Options

When `@theme_transparent_status_bar` is enabled:

| Option | Description | Default |
|--------|-------------|---------|
| `@theme_transparent_left_separator_inverse` | Inverse left separator for transparency | `` |
| `@theme_transparent_right_separator_inverse` | Inverse right separator for transparency | `` |

### Bar Layout

The `@theme_bar_layout` option controls how the status bar is displayed:

- **`single`** (default): Traditional single status bar with session, windows, and plugins
- **`double`**: Two status lines - one for session/windows, another for plugins

```bash
# Enable double bar layout
set -g @theme_bar_layout 'double'
```

### Available Colors

You can use these colors for any `accent_color` or `accent_color_icon` option:

| Color | Hex | Color | Hex |
|-------|-----|-------|-----|
| `bg` | `#1a1b26` | `blue` | `#7aa2f7` |
| `bg_dark` | `#16161e` | `blue0` | `#3d59a1` |
| `bg_highlight` | `#292e42` | `blue1` | `#2ac3de` |
| `fg` | `#c0caf5` | `blue2` | `#0db9d7` |
| `fg_dark` | `#a9b1d6` | `cyan` | `#7dcfff` |
| `red` | `#f7768e` | `green` | `#9ece6a` |
| `red1` | `#db4b4b` | `green1` | `#73daca` |
| `orange` | `#ff9e64` | `green2` | `#41a6b5` |
| `yellow` | `#e0af68` | `teal` | `#1abc9c` |
| `magenta` | `#bb9af7` | `purple` | `#9d7cd8` |
| `magenta2` | `#ff007c` | `white` | `#ffffff` |

---

## 🔌 Plugins

Enable plugins by adding them to the `@theme_plugins` option:

```bash
set -g @theme_plugins 'cpu,memory,network,git,datetime'
```

### System Monitoring

#### CPU

Displays current CPU usage percentage.

| Option | Description | Default |
|--------|-------------|---------|
| `@theme_plugin_cpu_icon` | Plugin icon | ` ` |
| `@theme_plugin_cpu_accent_color` | Background color | `yellow` |
| `@theme_plugin_cpu_accent_color_icon` | Icon background color | `orange` |

#### Memory

Displays current memory usage.

| Option | Description | Default |
|--------|-------------|---------|  
| `@theme_plugin_memory_icon` | Plugin icon | ` ` |
| `@theme_plugin_memory_accent_color` | Background color | `magenta` |
| `@theme_plugin_memory_accent_color_icon` | Icon background color | `purple` |
| `@theme_plugin_memory_format` | Display format: `percent` or `usage` | `percent` |

**Format options:**
- `percent`: Shows percentage (e.g., `45%`)
- `usage`: Shows used/total (e.g., `4.2G/16G`)

#### Load Average

Displays system load average (1, 5, and/or 15 minute averages).

| Option | Description | Default |
|--------|-------------|---------|  
| `@theme_plugin_loadavg_icon` | Plugin icon | `󰊚 ` |
| `@theme_plugin_loadavg_accent_color` | Background color | `yellow` |
| `@theme_plugin_loadavg_accent_color_icon` | Icon background color | `blue0` |
| `@theme_plugin_loadavg_format` | Display format | `1` |

**Format options:**
- `1`: Shows 1-minute load average (e.g., `1.23`)
- `5`: Shows 5-minute load average
- `15`: Shows 15-minute load average
- `all`: Shows all three (e.g., `1.23 1.45 1.67`)

#### Disk

Displays disk usage for a specified mount point.

| Option | Description | Default |
|--------|-------------|---------|  
| `@theme_plugin_disk_icon` | Plugin icon | `󰋊 ` |
| `@theme_plugin_disk_accent_color` | Background color | `cyan` |
| `@theme_plugin_disk_accent_color_icon` | Icon background color | `blue0` |
| `@theme_plugin_disk_mount` | Mount point to monitor | `/` |
| `@theme_plugin_disk_format` | Display format | `percent` |

**Format options:**
- `percent`: Shows percentage used (e.g., `45%`)
- `usage`: Shows used/total (e.g., `234G/500G`)
- `free`: Shows free space (e.g., `266G`)

#### NetworkDisplays network download/upload speeds.

> **Note:** This plugin uses a 1-second `sleep` to calculate network speed, which may cause minor delays during each status refresh. Consider using a longer tmux `status-interval` (e.g., 5+ seconds) when using this plugin.

| Option | Description | Default |
|--------|-------------|---------|
| `@theme_plugin_network_icon` | Plugin icon | `󰛳 ` |
| `@theme_plugin_network_accent_color` | Background color | `cyan` |
| `@theme_plugin_network_accent_color_icon` | Icon background color | `blue2` |
| `@theme_plugin_network_interface` | Network interface (auto-detected if empty) | `""` |

#### Uptime

Displays system uptime.

| Option | Description | Default |
|--------|-------------|---------|
| `@theme_plugin_uptime_icon` | Plugin icon | `󰔟 ` |
| `@theme_plugin_uptime_accent_color` | Background color | `green1` |
| `@theme_plugin_uptime_accent_color_icon` | Icon background color | `teal` |

### Development

#### Git

Displays current git branch and status. **Only shows when in a git repository.**

| Option | Description | Default |
|--------|-------------|---------|
| `@theme_plugin_git_icon` | Plugin icon | ` ` |
| `@theme_plugin_git_accent_color` | Background color | `green` |
| `@theme_plugin_git_accent_color_icon` | Icon background color | `green2` |

**Status indicators:**
- `~N`: N files modified
- `+N`: N untracked files

#### Docker

Displays Docker container status. **Only shows when Docker is running and has containers.**

| Option | Description | Default |
|--------|-------------|---------|
| `@theme_plugin_docker_icon` | Plugin icon | ` ` |
| `@theme_plugin_docker_accent_color` | Background color | `blue` |
| `@theme_plugin_docker_accent_color_icon` | Icon background color | `blue0` |

**Status indicators:**
- `N`: N running containers
- `⏹N`: N stopped containers

#### Kubernetes

Displays current Kubernetes context (and optionally namespace).

| Option | Description | Default |
|--------|-------------|---------|
| `@theme_plugin_kubernetes_icon` | Plugin icon | `󱃾 ` |
| `@theme_plugin_kubernetes_accent_color` | Background color | `purple` |
| `@theme_plugin_kubernetes_accent_color_icon` | Icon background color | `magenta` |
| `@theme_plugin_kubernetes_show_namespace` | Show namespace after context | `false` |

### Information

#### Datetime

Displays current date and time.

| Option | Description | Default |
|--------|-------------|---------|
| `@theme_plugin_datetime_icon` | Plugin icon | ` ` |
| `@theme_plugin_datetime_accent_color` | Background color | `blue0` |
| `@theme_plugin_datetime_accent_color_icon` | Icon background color | `blue` |
| `@theme_plugin_datetime_format` | strftime format string | `%D %H:%M:%S` |

#### Hostname

Displays the system hostname.

| Option | Description | Default |
|--------|-------------|---------|
| `@theme_plugin_hostname_icon` | Plugin icon | `󰒋 ` |
| `@theme_plugin_hostname_accent_color` | Background color | `orange` |
| `@theme_plugin_hostname_accent_color_icon` | Icon background color | `red` |

#### Weather

Displays current weather information. Requires `curl`. Note: `jq` is optional and only needed for auto-location detection via IP; if you provide a location via `@theme_plugin_weather_location`, the plugin works without `jq`.

| Option | Description | Default |
|--------|-------------|---------|
| `@theme_plugin_weather_icon` | Plugin icon | ` ` |
| `@theme_plugin_weather_accent_color` | Background color | `orange` |
| `@theme_plugin_weather_accent_color_icon` | Icon background color | `yellow` |
| `@theme_plugin_weather_format` | Weather format (e.g., temperature and humidity) | `%t H:%h` |
| `@theme_plugin_weather_location` | Location (city, country) | Auto-detected |
| `@theme_plugin_weather_unit` | Unit system: `u` (USCS), `m` (metric), `M` (metric m/s) | Auto |

**Format placeholders:**
- `%t`: Temperature
- `%c`: Condition
- `%h`: Humidity  
- `%w`: Wind speed

### Media & Applications

#### Spotify (Recommended)

Unified cross-platform Spotify plugin. **Only shows when music is playing.**

Supports multiple backends (auto-detected in order of preference):
- **macOS**: shpotify → osascript (AppleScript)
- **Linux**: playerctl (MPRIS)
- **Cross-platform**: spt (Spotify TUI)

| Option | Description | Default |
|--------|-------------|---------|  
| `@theme_plugin_spotify_icon` | Plugin icon | ` ` |
| `@theme_plugin_spotify_accent_color` | Background color | `green` |
| `@theme_plugin_spotify_accent_color_icon` | Icon background color | `green1` |
| `@theme_plugin_spotify_format` | Format string (`%artist%`, `%track%`, `%album%`) | `%artist% - %track%` |
| `@theme_plugin_spotify_max_length` | Maximum output length (0 = no limit) | `40` |
| `@theme_plugin_spotify_not_playing` | Text when not playing (empty = hide) | `""` |
| `@theme_plugin_spotify_backend` | Force backend: `auto`, `shpotify`, `playerctl`, `spt`, `osascript` | `auto` |
| `@theme_plugin_spotify_cache_ttl` | Cache TTL in seconds | `5` |

**Installation (macOS with shpotify):**
```bash
brew install shpotify
# Configure API credentials in ~/.shpotify.cfg
```

**Installation (Linux with playerctl):**
```bash
# Debian/Ubuntu
sudo apt install playerctl

# Arch
sudo pacman -S playerctl
```

#### Playerctl (Legacy)

Displays currently playing media via MPRIS. **Linux only.**

> **Note:** Consider using the unified `spotify` plugin instead, which provides cross-platform support.

| Option | Description | Default |
|--------|-------------|---------|
| `@theme_plugin_playerctl_icon` | Plugin icon | ` ` |
| `@theme_plugin_playerctl_accent_color` | Background color | `magenta` |
| `@theme_plugin_playerctl_accent_color_icon` | Icon background color | `purple` |
| `@theme_plugin_playerctl_format` | Playerctl format | `{{artist}} - {{title}}` |
| `@theme_plugin_playerctl_ignore_players` | Players to ignore | `""` |

#### Spotify (spt) - Legacy

Displays Spotify playback via `spt` CLI.

> **Note:** Consider using the unified `spotify` plugin instead, which auto-detects the best available backend.

| Option | Description | Default |
|--------|-------------|---------|
| `@theme_plugin_spt_icon` | Plugin icon | ` ` |
| `@theme_plugin_spt_accent_color` | Background color | `green` |
| `@theme_plugin_spt_accent_color_icon` | Icon background color | `green1` |
| `@theme_plugin_spt_format` | Format string for playback info | `%a - %t` |

### Package Managers

#### Homebrew

Displays number of outdated Homebrew packages. **Only shows when updates are available.** Works on macOS and Linux.

| Option | Description | Default |
|--------|-------------|---------|
| `@theme_plugin_homebrew_icon` | Plugin icon | `󰜋 ` |
| `@theme_plugin_homebrew_accent_color` | Background color | `yellow` |
| `@theme_plugin_homebrew_accent_color_icon` | Icon background color | `orange` |

#### Yay (AUR)

Displays number of outdated AUR packages. **Only shows when updates are available.** Arch Linux only.

| Option | Description | Default |
|--------|-------------|---------|
| `@theme_plugin_yay_icon` | Plugin icon | ` ` |
| `@theme_plugin_yay_accent_color` | Background color | `cyan` |
| `@theme_plugin_yay_accent_color_icon` | Icon background color | `blue` |

### Battery

Displays battery status with dynamic icons based on charging state.

| Option | Description | Default |
|--------|-------------|---------|
| `@theme_plugin_battery_icon_charging` | Icon when charging | ` ` |
| `@theme_plugin_battery_icon_discharging` | Icon when discharging | `󰁹 ` |
| `@theme_plugin_battery_accent_color` | Background color | `green` |
| `@theme_plugin_battery_accent_color_icon` | Icon background color | `green1` |

**Dynamic Colors Example:**

To enable dynamic colors that change based on battery level:

```bash
set -g @theme_plugin_battery_threshold_mode 'descending'
set -g @theme_plugin_battery_critical_threshold '10'
set -g @theme_plugin_battery_warning_threshold '30'
set -g @theme_plugin_battery_critical_color 'red'
set -g @theme_plugin_battery_critical_color_icon 'red1'
set -g @theme_plugin_battery_warning_color 'yellow'
set -g @theme_plugin_battery_warning_color_icon 'orange'
set -g @theme_plugin_battery_normal_color 'green'
set -g @theme_plugin_battery_normal_color_icon 'green1'
```

**Conditional Display Example:**

To only show battery when it's at 50% or below:

```bash
set -g @theme_plugin_battery_display_threshold '50'
set -g @theme_plugin_battery_display_condition 'le'
```

---

## 🎨 Threshold System (Dynamic Colors & Conditional Display)

The theme includes a powerful threshold system that can be applied to any plugin that displays numeric values. This enables:

1. **Dynamic Colors**: Change plugin colors based on the current value
2. **Conditional Display**: Only show plugins when values meet certain conditions

### Threshold Mode

Set `@theme_plugin_<name>_threshold_mode` to enable dynamic colors:

- **`descending`**: Low values are critical (red), high values are normal (green)
  - Example: Battery (10% = red, 80% = green)
- **`ascending`**: High values are critical (red), low values are normal (green)
  - Example: CPU usage (10% = green, 90% = red)

### Color Configuration

| Option | Description | Default |
|--------|-------------|---------|
| `@theme_plugin_<name>_threshold_mode` | `ascending` or `descending` | (disabled) |
| `@theme_plugin_<name>_critical_threshold` | Critical level threshold | `10` |
| `@theme_plugin_<name>_warning_threshold` | Warning level threshold | `30` |
| `@theme_plugin_<name>_critical_color` | Color for critical level | `red` |
| `@theme_plugin_<name>_critical_color_icon` | Icon color for critical level | `red1` |
| `@theme_plugin_<name>_warning_color` | Color for warning level | `yellow` |
| `@theme_plugin_<name>_warning_color_icon` | Icon color for warning level | `orange` |
| `@theme_plugin_<name>_normal_color` | Color for normal level | `green` |
| `@theme_plugin_<name>_normal_color_icon` | Icon color for normal level | `green1` |

### Conditional Display

| Option | Description | Default |
|--------|-------------|---------|
| `@theme_plugin_<name>_display_threshold` | Value threshold for display | (none) |
| `@theme_plugin_<name>_display_condition` | Condition for display | `always` |

**Display conditions:**
- `always`: Always display (default)
- `le`: Display when value <= threshold
- `lt`: Display when value < threshold
- `ge`: Display when value >= threshold
- `gt`: Display when value > threshold
- `eq`: Display when value == threshold

### Examples

**CPU with ascending threshold (high = bad):**
```bash
set -g @theme_plugin_cpu_threshold_mode 'ascending'
set -g @theme_plugin_cpu_critical_threshold '80'
set -g @theme_plugin_cpu_warning_threshold '50'
```

**Memory - only show when usage >= 70%:**
```bash
set -g @theme_plugin_memory_display_threshold '70'
set -g @theme_plugin_memory_display_condition 'ge'
```

**Disk with both dynamic colors and conditional display:**
```bash
# Dynamic colors
set -g @theme_plugin_disk_threshold_mode 'ascending'
set -g @theme_plugin_disk_critical_threshold '90'
set -g @theme_plugin_disk_warning_threshold '70'
# Only show when >= 50%
set -g @theme_plugin_disk_display_threshold '50'
set -g @theme_plugin_disk_display_condition 'ge'
```

---

## 📋 Example Configuration

```bash
# ~/.tmux.conf

# List of plugins
set -g @plugin 'tmux-plugins/tpm'
set -g @plugin 'tmux-plugins/tmux-sensible'
set -g @plugin 'fabioluciano/tmux-tokyo-night'

# Tokyo Night Theme Configuration
set -g @theme_variation 'night'
set -g @theme_plugins 'datetime,cpu,memory,disk,network,battery,spotify,git,docker'

# Plugin customization
set -g @theme_plugin_datetime_format '%H:%M'
set -g @theme_plugin_memory_format 'usage'
set -g @theme_plugin_disk_format 'usage'
set -g @theme_plugin_disk_mount '/'
set -g @theme_plugin_spotify_format '%artist% - %track%'
set -g @theme_plugin_spotify_max_length '30'

# Battery with dynamic colors
set -g @theme_plugin_battery_threshold_mode 'descending'
set -g @theme_plugin_battery_critical_threshold '10'
set -g @theme_plugin_battery_warning_threshold '30'

# Initialize TPM (keep this at the bottom)
run '~/.tmux/plugins/tpm/tpm'
```

## 🎨 Transparency Example

Enable transparency with custom separators:

```bash
# Enable transparency
set -g @theme_transparent_status_bar 'true'

# Optional: Custom separators for transparency
set -g @theme_left_separator ''
set -g @theme_right_separator ''
set -g @theme_transparent_left_separator_inverse ''
set -g @theme_transparent_right_separator_inverse ''
```

![Transparency Example](https://github.com/user-attachments/assets/56287ccb-9be9-4aa5-a2ab-ec48d2b2d08a)

---

## 🤝 Contributing

Contributions are welcome! Feel free to:

- Report bugs
- Suggest new features or plugins
- Submit pull requests

---

## 🔄 Migration from v1

### Breaking Changes in v2.0

1. **Plugin Architecture Refactored**: All plugins now follow a standardized architecture with consistent variable naming and caching support.

2. **Modular Separator System**: Separator building logic has been extracted to `src/separators.sh` for better maintainability and consistency across all plugin types.

3. **Caching System**: Plugins now use a file-based caching system located at `~/.cache/tmux-tokyo-night/`. Each plugin has its own cache file with configurable TTL.

4. **Conditional Plugins**: Git, Docker, Homebrew, Yay, and Spotify plugins are now conditional - they only appear when relevant (e.g., in a git repo, when Docker has containers, when package updates are available, when music is playing).

5. **Weather Plugin**: Now uses wttr.in's IP-based auto-detection by default. The `jq` dependency is no longer required for basic functionality.

6. **Battery Plugin**: Simplified architecture with support for dynamic threshold colors and charging/discharging icons.

7. **Spotify Plugin**: New unified cross-platform plugin that auto-detects the best available backend (shpotify, playerctl, spt, or osascript). The `spt` and `playerctl` plugins are now considered legacy.

8. **Cross-Platform Compatibility**: All plugins now properly detect and handle macOS vs Linux differences.

### Cache Management

The theme uses a file-based caching system to improve performance. Cache files are stored in `~/.cache/tmux-tokyo-night/`.

Clear the cache if you experience issues:

```bash
rm -rf ~/.cache/tmux-tokyo-night/
```

#### Configurable Cache TTL

All plugins support configurable cache TTL (Time To Live) via tmux options:

| Plugin | Option | Default | Description |
|--------|--------|---------|-------------|
| CPU | `@theme_plugin_cpu_cache_ttl` | `2` | 2 seconds |
| Memory | `@theme_plugin_memory_cache_ttl` | `5` | 5 seconds |
| Load Average | `@theme_plugin_loadavg_cache_ttl` | `5` | 5 seconds |
| Disk | `@theme_plugin_disk_cache_ttl` | `60` | 1 minute |
| Network | `@theme_plugin_network_cache_ttl` | `5` | 5 seconds |
| Uptime | `@theme_plugin_uptime_cache_ttl` | `60` | 1 minute |
| Battery | `@theme_plugin_battery_cache_ttl` | `30` | 30 seconds |
| Git | `@theme_plugin_git_cache_ttl` | `5` | 5 seconds |
| Docker | `@theme_plugin_docker_cache_ttl` | `10` | 10 seconds |
| Kubernetes | `@theme_plugin_kubernetes_cache_ttl` | `30` | 30 seconds |
| Weather | `@theme_plugin_weather_cache_ttl` | `900` | 15 minutes |
| Spotify | `@theme_plugin_spotify_cache_ttl` | `5` | 5 seconds |
| Homebrew | `@theme_plugin_homebrew_cache_ttl` | `1800` | 30 minutes |
| Yay | `@theme_plugin_yay_cache_ttl` | `1800` | 30 minutes |

**Example: Customize cache TTL**

```bash
# Weather updates every 30 minutes instead of 15
set -g @theme_plugin_weather_cache_ttl '1800'

# CPU updates every 10 seconds instead of 5
set -g @theme_plugin_cpu_cache_ttl '10'

# Homebrew checks every 2 hours instead of 1
set -g @theme_plugin_homebrew_cache_ttl '7200'
```

> **Note:** Lower TTL values provide more up-to-date information but may increase CPU usage. Higher values improve performance but show less current data.

---

## 📄 License

MIT License - See [LICENSE](LICENSE) for details.

---

<div align="center">
  <p>Made with ❤️ by <a href="https://github.com/fabioluciano">Fábio Luciano</a></p>
</div>
