#!/usr/bin/env bash

# Gruvbox Dark Theme - Semantic Color Mapping
# Retro groove theme with warm, earthy colors

# Populate the global THEME_COLORS array
THEME_COLORS=(
  # Core System Colors
  [none]="NONE"
  
  # Background Colors
  [background]="#282828"           # Main background (bg0)
  [background-darker]="#1d2021"    # Darker background (bg0_h)
  [surface]="#3c3836"              # Surface/card background (bg1)
  [overlay]="#504945"              # Overlay/modal background (bg2)
  
  # Text Colors  
  [text]="#ebdbb2"                 # Primary text (fg0)
  [text-secondary]="#d5c4a1"       # Secondary text (fg1)
  [text-muted]="#bdae93"           # Muted/comment text (fg2)
  [text-disabled]="#665c54"        # Disabled text (bg4)
  
  # Border Colors
  [border]="#504945"               # Default border (bg2)
  [border-light]="#665c54"         # Light border (bg4)
  [border-strong]="#7c6f64"        # Strong border (bg4)
  
  # Semantic Colors (Primary Actions)
  [primary]="#458588"              # Primary blue
  [primary-darker]="#076678"       # Darker primary (blue dark)
  [primary-lighter]="#83a598"      # Lighter primary (blue bright)
  [accent]="#b16286"               # Accent purple
  [secondary]="#665c54"            # Secondary (bg4)
  
  # Status Colors
  [success]="#98971a"              # Success green
  [success-subtle]="#b8bb26"       # Subtle success (green bright)
  [warning]="#d79921"              # Warning yellow
  [warning-strong]="#fe8019"       # Strong warning (orange)
  [error]="#cc241d"                # Error red
  [error-strong]="#fb4934"         # Strong error (red bright)
  [info]="#689d6a"                 # Info aqua
  [info-subtle]="#8ec07c"          # Subtle info (aqua bright)
  
  # Interactive States
  [hover]="#3c3836"                # Hover state (bg1)
  [active]="#458588"               # Active state (blue)
  [focus]="#83a598"                # Focus state (blue bright)
  [disabled]="#665c54"             # Disabled state (bg4)
  
  # Special Purpose
  [emphasis]="#fbf1c7"             # Maximum emphasis (fg0)
  [subtle]="#928374"               # Subtle emphasis (gray)
  [muted]="#665c54"                # Muted/de-emphasized (bg4)
)

export THEME_COLORS

# Helper function to get theme color
get_theme_color() {
    local color_name="$1"
    printf '%s' "${THEME_COLORS[$color_name]:-$color_name}"
}

# Helper function to check if color exists in theme
theme_has_color() {
    local color_name="$1"
    [[ -n "${THEME_COLORS[$color_name]}" ]]
}