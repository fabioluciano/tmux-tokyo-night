#!/usr/bin/env bash

# Dracula Theme - Semantic Color Mapping
# Dark theme with vibrant, high-contrast colors

# Populate the global THEME_COLORS array
THEME_COLORS=(
  # Core System Colors
  [none]="NONE"
  
  # Background Colors
  [background]="#282a36"           # Main background
  [background-darker]="#21222c"    # Darker background
  [surface]="#44475a"              # Surface/card background
  [overlay]="#6272a4"              # Overlay/modal background
  
  # Text Colors  
  [text]="#f8f8f2"                 # Primary text (foreground)
  [text-secondary]="#f8f8f2"       # Secondary text
  [text-muted]="#6272a4"           # Muted/comment text
  [text-disabled]="#44475a"        # Disabled text
  
  # Border Colors
  [border]="#44475a"               # Default border (current line)
  [border-light]="#6272a4"         # Light border (comment)
  [border-strong]="#bd93f9"        # Strong border (purple)
  
  # Semantic Colors (Primary Actions)
  [primary]="#8be9fd"              # Primary cyan
  [primary-darker]="#50fa7b"       # Darker primary (green)
  [primary-lighter]="#bd93f9"      # Lighter primary (purple)
  [accent]="#ff79c6"               # Accent pink
  [secondary]="#44475a"            # Secondary (current line)
  
  # Status Colors
  [success]="#50fa7b"              # Success green
  [success-subtle]="#8be9fd"       # Subtle success (cyan)
  [warning]="#f1fa8c"              # Warning yellow
  [warning-strong]="#ffb86c"       # Strong warning (orange)
  [error]="#ff5555"                # Error red
  [error-strong]="#ff79c6"         # Strong error (pink)
  [info]="#8be9fd"                 # Info cyan
  [info-subtle]="#bd93f9"          # Subtle info (purple)
  
  # Interactive States
  [hover]="#44475a"                # Hover state (current line)
  [active]="#bd93f9"               # Active state (purple)
  [focus]="#ff79c6"                # Focus state (pink)
  [disabled]="#6272a4"             # Disabled state (comment)
  
  # Special Purpose
  [emphasis]="#f8f8f2"             # Maximum emphasis (foreground)
  [subtle]="#6272a4"               # Subtle emphasis (comment)
  [muted]="#44475a"                # Muted/de-emphasized (current line)
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