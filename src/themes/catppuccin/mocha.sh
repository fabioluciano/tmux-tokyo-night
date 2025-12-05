#!/usr/bin/env bash

# Catppuccin Mocha Theme - Semantic Color Mapping
# Dark theme with warm, muted colors

# Populate the global THEME_COLORS array
THEME_COLORS=(
  # Core System Colors
  [none]="NONE"
  
  # Background Colors
  [background]="#1e1e2e"           # Main background (base)
  [background-darker]="#181825"    # Darker background (crust)
  [surface]="#313244"              # Surface/card background 
  [overlay]="#6c7086"              # Overlay/modal background
  
  # Text Colors  
  [text]="#cdd6f4"                 # Primary text
  [text-secondary]="#bac2de"       # Secondary text
  [text-muted]="#6c7086"           # Muted/comment text (overlay0)
  [text-disabled]="#585b70"        # Disabled text (overlay1)
  
  # Border Colors
  [border]="#45475a"               # Default border (surface1)
  [border-light]="#585b70"         # Light border (overlay1)
  [border-strong]="#6c7086"        # Strong border (overlay0)
  
  # Semantic Colors (Primary Actions)
  [primary]="#89b4fa"              # Primary blue
  [primary-darker]="#74c7ec"       # Darker primary (sapphire)
  [primary-lighter]="#b4befe"      # Lighter primary (lavender)
  [accent]="#cba6f7"               # Accent mauve
  [secondary]="#585b70"            # Secondary overlay1
  
  # Status Colors
  [success]="#a6e3a1"              # Success green
  [success-subtle]="#94e2d5"       # Subtle success (teal)
  [warning]="#f9e2af"              # Warning yellow
  [warning-strong]="#fab387"       # Strong warning (peach)
  [error]="#f38ba8"                # Error red
  [error-strong]="#eba0ac"         # Strong error (maroon)
  [info]="#89dceb"                 # Info sky
  [info-subtle]="#74c7ec"          # Subtle info (sapphire)
  
  # Interactive States
  [hover]="#313244"                # Hover state (surface0)
  [active]="#89b4fa"               # Active state (blue)
  [focus]="#cba6f7"                # Focus state (mauve)
  [disabled]="#6c7086"             # Disabled state (overlay0)
  
  # Special Purpose
  [emphasis]="#f5e0dc"             # Maximum emphasis (rosewater)
  [subtle]="#6c7086"               # Subtle emphasis (overlay0)
  [muted]="#585b70"                # Muted/de-emphasized (overlay1)
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