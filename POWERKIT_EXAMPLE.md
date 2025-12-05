# PowerKit Example Configuration

## Semantic Color Configuration

PowerKit uses semantic color names that work across multiple themes:

```bash
# ~/.tmux.conf

# PowerKit plugin options (replaces @theme_plugin_*)
set -g @powerkit_plugin_datetime_icon "󰥔"
set -g @powerkit_plugin_datetime_accent_color "accent"
set -g @powerkit_plugin_battery_icon "󰂄"
set -g @powerkit_plugin_battery_accent_color "success"

# Semantic color examples:
# accent, primary, secondary, success, warning, error, info
# surface, surface-elevated, border, border-strong
# text, text-muted, text-strong

# Window configuration
set -g @powerkit_window_default_fill "inactive"
set -g @powerkit_window_current_fill "active"

# Status bar plugins (same as before, but with semantic colors)
set -g @powerkit_plugins "datetime,battery"
set -g @powerkit_plugins_seperator ""

# Transparent background
set -g @powerkit_window_with_activity_style "bold"
set -g @powerkit_window_status_separator ""
```

## PowerKit Benefits

1. **Universal Theme Support**: Same configuration works across Tokyo Night, Dracula, Nord, etc.
2. **Semantic Color Names**: Colors like 'accent', 'success', 'warning' adapt to each theme
3. **Backward Compatibility**: Old @theme_* options still work as fallbacks
4. **Future-Proof**: Easy to add new themes without changing your config

## Theme Switching Example

```bash
# Switch to different Tokyo Night variants
set -g @powerkit_theme "tokyo-night-night"  # Default
set -g @powerkit_theme "tokyo-night-storm" 
set -g @powerkit_theme "tokyo-night-day"
set -g @powerkit_theme "tokyo-night-moon"

# Future theme support (examples)
set -g @powerkit_theme "dracula"
set -g @powerkit_theme "nord"
set -g @powerkit_theme "gruvbox-dark"
```

## Color Reference

PowerKit semantic colors for Tokyo Night Night theme:

- **accent**: `#7aa2f7` (blue) - Primary accent color
- **primary**: `#bb9af7` (purple) - Primary UI elements  
- **secondary**: `#7dcfff` (cyan) - Secondary elements
- **success**: `#9ece6a` (green) - Success states
- **warning**: `#e0af68` (yellow) - Warning states
- **error**: `#f7768e` (red) - Error states
- **info**: `#7dcfff` (cyan) - Information
- **surface**: `#1f2335` - Surface background
- **surface-elevated**: `#292e42` - Elevated surface
- **border**: `#414868` - Subtle borders
- **border-strong**: `#545c7e` - Strong borders
- **text**: `#c0caf5` - Primary text
- **text-muted**: `#565f89` - Muted text
- **text-strong**: `#ffffff` - Strong text