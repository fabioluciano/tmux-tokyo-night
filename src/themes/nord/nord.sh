#!/usr/bin/env bash

# Nord Theme - Semantic Color Mapping
# Arctic, north-bluish theme with cool colors

# Populate the global THEME_COLORS array
THEME_COLORS=(
  # Core System Colors
  [none]="NONE"
  
  # Background Colors
  [background]="#2e3440"           # Main background (nord0)
  [background-darker]="#3b4252"    # Darker background (nord1)
  [surface]="#434c5e"              # Surface/card background (nord2)
  [overlay]="#4c566a"              # Overlay/modal background (nord3)
  
  # Text Colors  
  [text]="#eceff4"                 # Primary text (nord6)
  [text-secondary]="#e5e9f0"       # Secondary text (nord5)
  [text-muted]="#d8dee9"           # Muted/comment text (nord4)
  [text-disabled]="#4c566a"        # Disabled text (nord3)
  
  # Border Colors
  [border]="#4c566a"               # Default border (nord3)
  [border-light]="#434c5e"         # Light border (nord2)
  [border-strong]="#5e81ac"        # Strong border (nord10)
  
  # Semantic Colors (Primary Actions)
  [primary]="#5e81ac"              # Primary blue (nord10)
  [primary-darker]="#81a1c1"       # Darker primary (nord9)
  [primary-lighter]="#88c0d0"      # Lighter primary (nord8)
  [accent]="#b48ead"               # Accent purple (nord15)
  [secondary]="#434c5e"            # Secondary (nord2)
  
  # Status Colors
  [success]="#a3be8c"              # Success green (nord14)
  [success-subtle]="#8fbcbb"       # Subtle success (nord7)
  [warning]="#ebcb8b"              # Warning yellow (nord13)
  [warning-strong]="#d08770"       # Strong warning (orange nord12)
  [error]="#bf616a"                # Error red (nord11)
  [error-strong]="#bf616a"         # Strong error (same as error)
  [info]="#88c0d0"                 # Info cyan (nord8)
  [info-subtle]="#8fbcbb"          # Subtle info (nord7)
  
  # Interactive States
  [hover]="#434c5e"                # Hover state (nord2)
  [active]="#5e81ac"               # Active state (nord10)
  [focus]="#88c0d0"                # Focus state (nord8)
  [disabled]="#4c566a"             # Disabled state (nord3)
  
  # Special Purpose
  [emphasis]="#eceff4"             # Maximum emphasis (nord6)
  [subtle]="#d8dee9"               # Subtle emphasis (nord4)
  [muted]="#4c566a"                # Muted/de-emphasized (nord3)
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