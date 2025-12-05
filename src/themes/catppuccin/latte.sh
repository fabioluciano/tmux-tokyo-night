#!/usr/bin/env bash

# Catppuccin Latte Theme - Semantic Color Mapping  
# Light theme with warm, soft colors

# Populate the global THEME_COLORS array
THEME_COLORS=(
  # Core System Colors
  [none]="NONE"
  
  # Background Colors
  [background]="#eff1f5"           # Main background (base)
  [background-darker]="#e6e9ef"    # Darker background (mantle)
  [surface]="#dce0e8"              # Surface/card background (crust)
  [overlay]="#9ca0b0"              # Overlay/modal background
  
  # Text Colors  
  [text]="#4c4f69"                 # Primary text
  [text-secondary]="#5c5f77"       # Secondary text
  [text-muted]="#9ca0b0"           # Muted/comment text (overlay0)
  [text-disabled]="#acb0be"        # Disabled text (overlay1)
  
  # Border Colors
  [border]="#ccd0da"               # Default border (surface1)
  [border-light]="#acb0be"         # Light border (overlay1)
  [border-strong]="#9ca0b0"        # Strong border (overlay0)
  
  # Semantic Colors (Primary Actions)
  [primary]="#1e66f5"              # Primary blue
  [primary-darker]="#209fb5"       # Darker primary (sapphire)
  [primary-lighter]="#7287fd"      # Lighter primary (lavender)
  [accent]="#8839ef"               # Accent mauve
  [secondary]="#acb0be"            # Secondary overlay1
  
  # Status Colors
  [success]="#40a02b"              # Success green
  [success-subtle]="#179299"       # Subtle success (teal)
  [warning]="#df8e1d"              # Warning yellow
  [warning-strong]="#fe640b"       # Strong warning (peach)
  [error]="#d20f39"                # Error red
  [error-strong]="#e64553"         # Strong error (maroon)
  [info]="#04a5e5"                 # Info sky
  [info-subtle]="#209fb5"          # Subtle info (sapphire)
  
  # Interactive States
  [hover]="#dce0e8"                # Hover state (crust)
  [active]="#1e66f5"               # Active state (blue)
  [focus]="#8839ef"                # Focus state (mauve)
  [disabled]="#9ca0b0"             # Disabled state (overlay0)
  
  # Special Purpose
  [emphasis]="#dc8a78"             # Maximum emphasis (rosewater)
  [subtle]="#9ca0b0"               # Subtle emphasis (overlay0)
  [muted]="#acb0be"                # Muted/de-emphasized (overlay1)
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