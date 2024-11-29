<div align="center">
  <h1>Tokyo Night Tmux Theme</h1>
  
  <h4>A Tokyo Night tmux theme directly inspired from Tokyo Night vim theme</h4>
    
  ---
    
  **[<kbd> <br> Features <br> </kbd>][features]**
  **[<kbd> <br> Screenshots <br> </kbd>][screenshots]**
  **[<kbd> <br> Install <br> </kbd>][install]**
  **[<kbd> <br> Available Configurations <br> </kbd>][available-configurations]**
  **[<kbd> <br> Plugins <br> </kbd>][plugins]**
  
  ---
    
</div>

## Features

- [Transparency support](#Transparency-examples)

## Plugins

- **Datetime** - Show datetime;
- **Weather** - Show weather;
- **Playerctl** - Show playerctl;
- **Spt** - Show Spotify;
- **Homebrew** - Show Homebrew;
- **yay** - Show yay;
- **battery** - Show battery;

## Screenshots

### Tokyo Night - Default Variation

| Inactive                                                                                                             | Active                                                                                                                      |
| -------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------- |
| ![Tokyo Night tmux theme - Default Variation](./assets/tokyo-night.png "Tokyo Night tmux theme - Default Variation") | ![Tokyo Night tmux theme - Default Variation](./assets/tokyo-night-active.png "Tokyo Night tmux theme - Default Variation") |

## Install

Add plugin to the list of `TPM` plugins in `.tmux.conf`:

```
set -g @plugin 'fabioluciano/tmux-tokyo-night'
```

Hit <kbd>prefix</kbd> + <kbd>I</kbd> to fetch the plugin and source it. You can now use the plugin.

## Available Configurations

| Configuration                       | Description                               | Avaliable Options                                                       | Default            |
| ----------------------------------- | ----------------------------------------- | ----------------------------------------------------------------------- | ------------------ |
| `@theme_variation`                  | The tokyo night theme variation to be use | `night`, `storm`, `moon`                                                | `night`            |
| `@theme_active_pane_border_style`   |                                           |                                                                         | `#737aa2`          |
| `@theme_inactive_pane_border_style` |                                           |                                                                         | `#292e42`          |
| `@theme_left_separator`             |                                           |                                                                         | ``                |
| `@theme_right_separator`            |                                           |                                                                         | ``                |
| `@theme_window_with_activity_style` |                                           |                                                                         | `italics`          |
| `@theme_status_bell_style`          |                                           |                                                                         | `bold`             |
| `@theme_plugins`                    |                                           | `datetime`, `weather`, `playerctl`, `spt`, `homebrew`, `yay`, `battery` | `datetime,weather` |
| `@theme_disable_plugins`            | Disables plugins                          | `1`, `0`                                                                | `0`                |

## Plugins

### Datetime

> Prints informations about the current date and time.

| Configuration                              | Description | Avaliable Options | Default |
| ------------------------------------------ | ----------- | ----------------- | ------- |
| `@theme_plugin_datetime_icon`              |             | Any character 📅  | Nerd Font 'Calendar' icon        |
| `@theme_plugin_datetime_accent_color`      |             |                   |         |
| `@theme_plugin_datetime_accent_color_icon` |             |                   |         |
| `@theme_plugin_datetime_format`            |             |                   |         |

### Weather

> Prints informations about the current weather. It uses `jq` to parse the response. Make shure to have it;

| Configuration                             | Description | Avaliable Options | Default |
| ----------------------------------------- | ----------- | ----------------- | ------- |
| `@theme_plugin_weather_icon`              |             | Any character 🌡️  |  Font Awesome 'Cloud' icon        |
| `@theme_plugin_weather_accent_color`      |             |                   |         |
| `@theme_plugin_weather_accent_color_icon` |             |                   |         |
| `@theme_plugin_weather_format`            | Format for displaying weather information | `%t`, `%c`, `%h`, `%w` (temperature, condition, humidity, wind) | `%t+H:%h` |
| `@theme_plugin_weather_location`          | Location for weather (city/country)   | `"City, Country"`  | IP-based location detection |

#### Example
  ```
  set -g @theme_plugin_weather_location 'Blacksburg, United States'
  ```

### Playerctl

> Prints informations about the current song playing. Does not work in `MacOS`, because it uses `MPRIS`, and is only available in `Linux`.

| Configuration                               | Description | Avaliable Options | Default |
| ------------------------------------------- | ----------- | ----------------- | ------- |
| `@theme_plugin_playerctl_icon`              |             |                   |         |
| `@theme_plugin_playerctl_accent_color`      |             |                   |         |
| `@theme_plugin_playerctl_accent_color_icon` |             |                   |         |
| `@theme_plugin_playerctl_format`            |             |                   |         |

### Battery

Shows battery charging status (charging or discharging) and battery percentage.

| Configuration                                    | Description                        | Avaliable Options | Default  |
| ------------------------------------------------ | ---------------------------------- | ----------------- | -------- |
| `@theme_plugin_battery_charging_icon`            | Icon to display when charging      | Any character     |         |
| `@theme_plugin_battery_discharging`              | Icon to display when on battery    | Any character     | 󰁹        |
| `@theme_plugin_battery_red_threshold`            | Show in red when below this %      | 0-100             | 10       |
| `@theme_plugin_battery_yellow_threshold`         | Show in yellow when below this %   | 0-100             | 30       |
| `@theme_plugin_battery_red_accent_color`         | Color when < red threshold         | Palette color     | red      |
| `@theme_plugin_battery_red_accent_color_icon`    | Icon color when < red threshold    | Palette color     | magenta2 |
| `@theme_plugin_battery_yellow_accent_color`      | Color when < yellow threshold      | Palette color     | yellow   |
| `@theme_plugin_battery_yellow_accent_color_icon` | Icon color when < yellow threshold | Palette color     | orange   |
| `@theme_plugin_battery_green_accent_color`       | Color when > yellow threshold      | Palette color     | blue7    |
| `@theme_plugin_battery_green_accent_color_icon`  | Icon color when > yellow threshold | Palette color     | blue0    |

### Example configuration

tmux.conf

```bash
set -g @plugin 'tmux-plugins/tpm'

set -g @plugin 'tmux-plugins/tmux-pain-control'
set -g @plugin 'tmux-plugins/tmux-sensible'
set -g @plugin 'tmux-plugins/tmux-logging'

set -g @plugin 'fabioluciano/tmux-tokyo-night'

### Tokyo Night Theme configuration
set -g @theme_variation 'moon'
set -g @theme_left_separator ''
set -g @theme_right_separator ''
set -g @theme_plugins 'datetime,weather,playerctl,yay'

run '~/.tmux/plugins/tpm/tpm'
```

### Transparency examples

Enable transparency with default separators:

```bash
### Enable transparency
set -g @theme_transparent_status_bar 'true'
```

![Screenshot 2024-09-07 at 12 41 12](https://github.com/user-attachments/assets/56287ccb-9be9-4aa5-a2ab-ec48d2b2d08a)

####

Can also use custom separators:

```bash
### Enable transparency
set -g @theme_left_separator ''
set -g @theme_right_separator ''
set -g @theme_transparent_status_bar 'true'
set -g @theme_transparent_left_separator_inverse ''
set -g @theme_transparent_right_separator_inverse ''

```

![Screenshot 2024-09-07 at 12 39 35](https://github.com/user-attachments/assets/a33417b1-34e0-4212-952e-7ef1e240e943)

[features]: #features
[screenshots]: #screenshots
[install]: #install
[available-configurations]: #available-configurations
[plugins]: #plugins
