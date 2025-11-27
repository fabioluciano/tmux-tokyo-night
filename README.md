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
- 🔌 **15 built-in plugins** for system monitoring and information display
- 🪟 **Transparency support** with customizable separators
- 📊 **Double bar layout** option for separating windows and plugins
- ⚡ **Smart caching system** for improved performance (configurable TTL per plugin)
- 🔧 **Highly customizable** with per-plugin configuration options
- 🎯 **Conditional plugins** (git, docker) that only appear when relevant

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

#### Network

Displays network download/upload speeds.

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

Displays current Kubernetes context and namespace.

| Option | Description | Default |
|--------|-------------|---------|
| `@theme_plugin_kubernetes_icon` | Plugin icon | `󱃾 ` |
| `@theme_plugin_kubernetes_accent_color` | Background color | `purple` |
| `@theme_plugin_kubernetes_accent_color_icon` | Icon background color | `magenta` |
| `@theme_plugin_kubernetes_show_namespace` | Show namespace | `true` |

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

#### Playerctl

Displays currently playing media. **Linux only** (uses MPRIS).

| Option | Description | Default |
|--------|-------------|---------|
| `@theme_plugin_playerctl_icon` | Plugin icon | ` ` |
| `@theme_plugin_playerctl_accent_color` | Background color | `magenta` |
| `@theme_plugin_playerctl_accent_color_icon` | Icon background color | `purple` |
| `@theme_plugin_playerctl_format` | Playerctl format | `{{artist}} - {{title}}` |
| `@theme_plugin_playerctl_ignore_players` | Players to ignore | `""` |

#### Spotify (spt)

Displays Spotify playback via `spt` CLI.

| Option | Description | Default |
|--------|-------------|---------|
| `@theme_plugin_spt_icon` | Plugin icon | ` ` |
| `@theme_plugin_spt_accent_color` | Background color | `green` |
| `@theme_plugin_spt_accent_color_icon` | Icon background color | `green1` |
| `@theme_plugin_spt_format` | Format string for playback info | `%a - %t` |

### Package Managers

#### Homebrew

Displays number of outdated Homebrew packages. **macOS only.**

| Option | Description | Default |
|--------|-------------|---------|
| `@theme_plugin_homebrew_icon` | Plugin icon | `󰜋 ` |
| `@theme_plugin_homebrew_accent_color` | Background color | `yellow` |
| `@theme_plugin_homebrew_accent_color_icon` | Icon background color | `orange` |

#### Yay (AUR)

Displays number of outdated AUR packages. **Arch Linux only.**

| Option | Description | Default |
|--------|-------------|---------|
| `@theme_plugin_yay_icon` | Plugin icon | ` ` |
| `@theme_plugin_yay_accent_color` | Background color | `cyan` |
| `@theme_plugin_yay_accent_color_icon` | Icon background color | `blue` |

### Battery

Displays battery status with dynamic colors based on charge level.

| Option | Description | Default |
|--------|-------------|---------|
| `@theme_plugin_battery_charging_icon` | Charging icon | `` |
| `@theme_plugin_battery_discharging_icon` | Discharging icon | `󰁹` |
| `@theme_plugin_battery_red_threshold` | Red warning threshold | `10` |
| `@theme_plugin_battery_yellow_threshold` | Yellow warning threshold | `30` |
| `@theme_plugin_battery_red_accent_color` | Color below red threshold | `red` |
| `@theme_plugin_battery_red_accent_color_icon` | Icon color below red threshold | `magenta2` |
| `@theme_plugin_battery_yellow_accent_color` | Color below yellow threshold | `yellow` |
| `@theme_plugin_battery_yellow_accent_color_icon` | Icon color below yellow threshold | `orange` |
| `@theme_plugin_battery_green_accent_color` | Color above yellow threshold | `blue7` |
| `@theme_plugin_battery_green_accent_color_icon` | Icon color above yellow threshold | `blue0` |

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
set -g @theme_plugins 'datetime,cpu,memory,network,git,docker,kubernetes'

# Plugin customization
set -g @theme_plugin_datetime_format '%H:%M'
set -g @theme_plugin_memory_format 'usage'
set -g @theme_plugin_kubernetes_show_namespace 'true'

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

2. **Caching System**: Plugins now use a file-based caching system located at `~/.cache/tmux-tokyo-night/`. Each plugin has its own cache file with configurable TTL.

3. **Conditional Plugins**: Git and Docker plugins are now conditional - they only appear when you're in a git repository or when Docker has containers.

4. **Weather Plugin**: Now uses wttr.in's IP-based auto-detection by default. The `jq` dependency is no longer required for basic functionality.

5. **Battery Plugin**: Simplified architecture - no longer uses dynamic color changing via templates. Uses standard plugin format.

### Cache Management

Clear the cache if you experience issues:

```bash
rm -rf ~/.cache/tmux-tokyo-night/
```

Cache TTL can be configured per plugin:

| Plugin | Option | Default |
|--------|--------|---------|
| Weather | `@theme_plugin_weather_cache_ttl` | `900` (15 min) |
| CPU | Built-in | `5` (5 sec) |
| Memory | Built-in | `5` (5 sec) |
| Network | Built-in | `2` (2 sec) |
| Kubernetes | Built-in | `30` (30 sec) |

---

## 📄 License

MIT License - See [LICENSE](LICENSE) for details.

---

<div align="center">
  <p>Made with ❤️ by <a href="https://github.com/fabioluciano">Fábio Luciano</a></p>
</div>
