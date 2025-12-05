#!/usr/bin/env bash

# Tokyo Night Day - Semantic Color Mapping

# Populate the global THEME_COLORS array
THEME_COLORS=(
  # Core System Colors
  [none]="NONE"
  
  # Background Colors (Day variant - light theme)
  [background]="#e1e2e7"           # Main background (light)
  [background-darker]="#d0d0d0"    # Darker background variant
  [surface]="#f7f7f7"              # Surface/card background
  [overlay]="#c4c8da"              # Overlay/modal background
  
  # Text Colors (Day - inverted for light theme)
  [text]="#3760bf"                 # Primary text (dark blue)
  [text-secondary]="#6172b0"       # Secondary text
  [text-muted]="#8990b3"           # Muted/comment text
  [text-disabled]="#9699a3"        # Disabled text
  
  # Border Colors
  [border]="#c4c8da"               # Default border
  [border-light]="#d5d6db"         # Light border
  [border-strong]="#a1a6c5"        # Strong border
  
  # Semantic Colors (Primary Actions - adapted for light theme)
  [primary]="#2e7de9"              # Primary blue (darker for contrast)
  [primary-darker]="#188092"       # Darker primary
  [primary-lighter]="#0f4b6e"      # Lighter primary
  [accent]="#5a4fcf"               # Accent purple
  [secondary]="#6172b0"            # Secondary blue-gray
  
  # Status Colors (adapted for light theme)
  [success]="#33635c"              # Success green (darker)
  [success-subtle]="#0f4b6e"       # Subtle success
  [warning]="#8c6c3e"              # Warning yellow (darker)
  [warning-strong]="#b15c00"       # Strong warning (orange)
  [error]="#c64343"                # Error red
  [error-strong]="#a73636"         # Strong error
  [info]="#0f4b6e"                 # Info cyan (darker)
  [info-subtle]="#188092"          # Subtle info
  
  # Interactive States
  [hover]="#f0f0f0"                # Hover state
  [active]="#2e7de9"               # Active state  
  [focus]="#2e7de9"                # Focus state
  [disabled]="#8990b3"             # Disabled state
  
  # Special Purpose
  [emphasis]="#16161e"             # Maximum emphasis (dark text)
  [subtle]="#6172b0"               # Subtle emphasis
  [muted]="#8990b3"                # Muted/de-emphasized
  

)

export THEME_COLORS