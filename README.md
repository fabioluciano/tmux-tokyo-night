<h1 align="center">
  Tokyo Night Tmux Theme
</h1>

<h4 align="center">A Tokyo Night tmux theme directly inspired from Tokyo Night vim theme</h4>
<hr>
<p align="center">
  • <a href="#features">Features</a> •
  <a href="#screenshots">Screenshots</a> •
  <a href="#install">Install</a> •
  <a href="#available-configurations">Available Configurations</a> •
  <a href="#plugins">Plugins</a> •
</p>
<hr>

## Features
## Screenshots
### Tokyo Night - Default Variation
| Inactive  | Active   |
|-------------- | -------------- |
|![Tokyo Night tmux theme - Default Variation](./assets/tokyo-night.png "Tokyo Night tmux theme - Default Variation")| ![Tokyo Night tmux theme - Default Variation](./assets/tokyo-night-active.png "Tokyo Night tmux theme - Default Variation")|

## Install 
Add plugin to the list of `TPM` plugins in `.tmux.conf`:

```
set -g @plugin 'fabioluciano/tmux-tokyo-night/'
```

Hit <kbd>prefix</kbd> + <kbd>I</kbd> to fetch the plugin and source it. You can now use the plugin.
## Available Configurations
| Configuration | Description | Avaliable Options | Default |
|---------------- | --------------- | --------------- | --------------- |
| `@theme_variation`| The tokyo night theme variation to be use | `night`, `storm`, `moon` | `night` |

### Example configuration

tmux.conf
```

set -g @plugin 'tmux-plugins/tpm'

set -g @plugin 'tmux-plugins/tmux-pain-control'
set -g @plugin 'tmux-plugins/tmux-sensible'
set -g @plugin 'tmux-plugins/tmux-logging'

set -g @plugin 'fabioluciano/tmux-tokyo-night'

### Plugins Options
set -g @extrakto_popup_size 70%

############################

run '~/.tmux/plugins/tpm/tpm'
```
## Plugins

