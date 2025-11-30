# 🌃 Tokyo Night for tmux

A clean, dark tmux theme inspired by the [Tokyo Night](https://github.com/enkia/tokyo-night-vscode-theme) color scheme. Features a modular plugin system with 24 built-in plugins for displaying system information, development tools, and media status.

![Tokyo Night Theme](./assets/tokyo-night-bar.png)
![Tokyo Night Theme](./assets/tokyo-night-theme.png)

## ✨ Features

- 🎨 **Four color variations** - Night, Storm, Moon, and Day
- 🔌 **24 built-in plugins** - System monitoring, development tools, media players
- ⚡ **Performance optimized** - Intelligent caching system
- 🎯 **Fully customizable** - Colors, icons, formats, and separators
- 🖥️ **Cross-platform** - macOS, Linux, and BSD support
- ⌨️ **Interactive features** - Popup helpers and selectors

## 📚 Documentation

- **[Installation](../../wiki/Installation)** - Setup with TPM or manual installation
- **[Quick Start](../../wiki/Quick-Start)** - Get up and running in minutes
- **[Theme Variations](../../wiki/Theme-Variations)** - Explore Night, Storm, Moon, and Day
- **[Global Configuration](../../wiki/Global-Configuration)** - Configure status bar layout and separators
- **[Plugin System](../../wiki/Plugin-System-Overview)** - Complete reference for all 24 plugins
- **[Interactive Keybindings](../../wiki/Interactive-Keybindings)** - Popup helpers and selectors
- **[Custom Colors & Theming](../../wiki/Custom-Colors-Theming)** - Advanced customization
- **[Performance & Caching](../../wiki/Performance-Caching)** - Optimize for your workflow
- **[Troubleshooting](../../wiki/Troubleshooting)** - Common issues and solutions

## 🚀 Quick Start

### Installation

Add to your `~/.tmux.conf`:

```bash
set -g @plugin 'fabioluciano/tmux-tokyo-night'
```

Press `prefix + I` to install with [TPM](https://github.com/tmux-plugins/tpm).

### Basic Configuration

```bash
# Choose theme variation
set -g @theme_variation 'night'

# Enable plugins
set -g @theme_plugins 'datetime,weather,battery,cpu,memory'

# Auto-detect OS icon
set -g @theme_session_icon 'auto'
```

See **[Quick Start Guide](../../wiki/Quick-Start)** for more examples.

## 🎨 Theme Variations

| Variation | Description |
|-----------|-------------|
| `night` | Deep dark theme (default) |
| `storm` | Lighter dark theme |
| `moon` | Balanced medium theme |
| `day` | Light theme |

```bash
set -g @theme_variation 'night'
```

Learn more: **[Theme Variations](../../wiki/Theme-Variations)**

## ⌨️ Interactive Features

| Keybinding | Feature |
|------------|---------|
| `prefix + ?` | **Options viewer** - Browse all theme settings |
| `prefix + B` | **Keybindings viewer** - View all keybindings |
| `prefix + K` | **Kubernetes context selector** - Switch contexts |
| `prefix + N` | **Kubernetes namespace selector** - Switch namespaces |

![Options Viewer](./assets/keybinding-options-viewer.gif)

Learn more: **[Interactive Keybindings](../../wiki/Interactive-Keybindings)**

## 🔌 Available Plugins

The theme includes 24 built-in plugins organized by category:

### 📅 Time & Date
- **[datetime](../../wiki/Datetime)** - Customizable date and time display

### 🌡️ System Monitoring
- **[cpu](../../wiki/CPU)** - CPU usage with thresholds
- **[memory](../../wiki/Memory)** - RAM usage monitoring
- **[disk](../../wiki/Disk)** - Disk space tracking
- **[loadavg](../../wiki/LoadAvg)** - System load average
- **[temperature](../../wiki/Temperature)** - CPU temperature (Linux only)
- **[uptime](../../wiki/Uptime)** - System uptime

### 🌐 Network & Connectivity
- **[network](../../wiki/Network)** - Bandwidth monitoring
- **[wifi](../../wiki/WiFi)** - WiFi status and signal
- **[vpn](../../wiki/VPN)** - VPN connection status
- **[external_ip](../../wiki/External-IP)** - Public IP address
- **[bluetooth](../../wiki/Bluetooth)** - Bluetooth status
- **[weather](../../wiki/Weather)** - Weather conditions

### 💻 Development
- **[git](../../wiki/Git)** - Git branch and status
- **[docker](../../wiki/Docker)** - Container count
- **[kubernetes](../../wiki/Kubernetes)** - K8s context/namespace

### 📦 Package Managers
- **[homebrew](../../wiki/Homebrew)** - Brew updates (macOS)
- **[yay](../../wiki/Yay)** - AUR updates (Arch)

### 🎵 Media
- **[spotify](../../wiki/Spotify)** - Now playing
- **[playerctl](../../wiki/Playerctl)** - Media player
- **[volume](../../wiki/Volume)** - Volume level

### 🖥️ System Info
- **[battery](../../wiki/Battery)** - Battery status
- **[hostname](../../wiki/Hostname)** - System hostname

**Enable plugins:**
```bash
set -g @theme_plugins 'datetime,battery,cpu,memory,git,docker'
```

See **[Plugin System Overview](../../wiki/Plugin-System-Overview)** for complete documentation.

## ⚙️ Configuration

### Global Options

```bash
# Theme variation
set -g @theme_variation 'night'

# Status bar position
set -g @theme_status_position 'bottom'

# Separators
set -g @theme_left_separator ''
set -g @theme_right_separator ''

# Session icon (auto-detects OS)
set -g @theme_session_icon 'auto'
```

### Plugin Customization

Each plugin supports:
- **Icon** - Custom icon character
- **Accent color** - Background color
- **Cache TTL** - Update frequency

```bash
# Example: Customize CPU plugin
set -g @theme_plugin_cpu_icon ''
set -g @theme_plugin_cpu_accent_color 'red'
set -g @theme_plugin_cpu_cache_ttl 2
```

Learn more:
- **[Global Configuration](../../wiki/Global-Configuration)**
- **[Custom Colors & Theming](../../wiki/Custom-Colors-Theming)**
- **[Performance & Caching](../../wiki/Performance-Caching)**

## 📝 Example Configuration

```bash
# ~/.tmux.conf

# Theme variation
set -g @theme_variation 'night'

# Auto-detect OS icon
set -g @theme_session_icon 'auto'

# Enable plugins
set -g @theme_plugins 'datetime,weather,battery,cpu,memory,git,docker,kubernetes'

# Customize datetime
set -g @theme_plugin_datetime_format 'datetime'

# Set weather location
set -g @theme_plugin_weather_location 'New York'

# Kubernetes with namespace
set -g @theme_plugin_kubernetes_show_namespace 'true'

# Load TPM
set -g @plugin 'tmux-plugins/tpm'
set -g @plugin 'fabioluciano/tmux-tokyo-night'
run '~/.tmux/plugins/tpm/tpm'
```

See **[Quick Start](../../wiki/Quick-Start)** for more configuration examples.

## 🙏 Credits

- Color scheme inspired by [Tokyo Night](https://github.com/enkia/tokyo-night-vscode-theme) by enkia
- Weather data provided by [wttr.in](https://wttr.in)

## 📄 License

MIT License - see LICENSE file for details

