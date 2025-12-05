#!/usr/bin/env bash

# One Dark Theme - Semantic Color Mapping
# Inspired by Atom's One Dark theme

# Populate the global THEME_COLORS array
THEME_COLORS=(
  # Core System Colors
  [none]="NONE"
  
  # Background Colors
  [background]="#282c34"           # Main background
  [background-darker]="#21252b"    # Darker background
  [surface]="#3e4451"              # Surface/card background
  [overlay]="#4b5263"              # Overlay/modal background
  
  # Text Colors  
  [text]="#abb2bf"                 # Primary text
  [text-secondary]="#9da5b4"       # Secondary text
  [text-muted]="#5c6370"           # Muted/comment text
  [text-disabled]="#4b5263"        # Disabled text
  
  # Border Colors
  [border]="#4b5263"               # Default border
  [border-light]="#5c6370"         # Light border
  [border-strong]="#636d83"        # Strong border
  
  # Semantic Colors (Primary Actions)
  [primary]="#61afef"              # Primary blue
  [primary-darker]="#528bff"       # Darker primary
  [primary-lighter]="#73c7ec"      # Lighter primary
  [accent]="#c678dd"               # Accent purple
  [secondary]="#4b5263"            # Secondary
  
  # Status Colors
  [success]="#98c379"              # Success green
  [success-subtle]="#56b6c2"       # Subtle success (cyan)
  [warning]="#e5c07b"              # Warning yellow
  [warning-strong]="#d19a66"       # Strong warning (orange)
  [error]="#e06c75"                # Error red
  [error-strong]="#be5046"         # Strong error
  [info]="#56b6c2"                 # Info cyan
  [info-subtle]="#61afef"          # Subtle info (blue)
  
  # Interactive States
  [hover]="#3e4451"                # Hover state
  [active]="#61afef"               # Active state (blue)
  [focus]="#c678dd"                # Focus state (purple)
  [disabled]="#5c6370"             # Disabled state
  
  # Special Purpose
  [emphasis]="#ffffff"             # Maximum emphasis
  [subtle]="#5c6370"               # Subtle emphasis
  [muted]="#4b5263"                # Muted/de-emphasized
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