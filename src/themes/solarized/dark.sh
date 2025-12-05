#!/usr/bin/env bash

# Solarized Dark Theme - Semantic Color Mapping
# Precision colors for machines and people

# Populate the global THEME_COLORS array
THEME_COLORS=(
  # Core System Colors
  [none]="NONE"
  
  # Background Colors
  [background]="#002b36"           # Main background (base03)
  [background-darker]="#073642"    # Darker background (base02)
  [surface]="#586e75"              # Surface/card background (base01)
  [overlay]="#657b83"              # Overlay/modal background (base00)
  
  # Text Colors  
  [text]="#839496"                 # Primary text (base0)
  [text-secondary]="#93a1a1"       # Secondary text (base1)
  [text-muted]="#586e75"           # Muted/comment text (base01)
  [text-disabled]="#073642"        # Disabled text (base02)
  
  # Border Colors
  [border]="#073642"               # Default border (base02)
  [border-light]="#586e75"         # Light border (base01)
  [border-strong]="#657b83"        # Strong border (base00)
  
  # Semantic Colors (Primary Actions)
  [primary]="#268bd2"              # Primary blue
  [primary-darker]="#2aa198"       # Darker primary (cyan)
  [primary-lighter]="#6c71c4"      # Lighter primary (violet)
  [accent]="#d33682"               # Accent magenta
  [secondary]="#586e75"            # Secondary (base01)
  
  # Status Colors
  [success]="#859900"              # Success green
  [success-subtle]="#2aa198"       # Subtle success (cyan)
  [warning]="#b58900"              # Warning yellow
  [warning-strong]="#cb4b16"       # Strong warning (orange)
  [error]="#dc322f"                # Error red
  [error-strong]="#d33682"         # Strong error (magenta)
  [info]="#268bd2"                 # Info blue
  [info-subtle]="#2aa198"          # Subtle info (cyan)
  
  # Interactive States
  [hover]="#073642"                # Hover state (base02)
  [active]="#268bd2"               # Active state (blue)
  [focus]="#d33682"                # Focus state (magenta)
  [disabled]="#586e75"             # Disabled state (base01)
  
  # Special Purpose
  [emphasis]="#fdf6e3"             # Maximum emphasis (base3)
  [subtle]="#586e75"               # Subtle emphasis (base01)
  [muted]="#073642"                # Muted/de-emphasized (base02)
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