#!/usr/bin/env bash

# Tokyo Night Storm - Semantic Color Mapping

# Populate the global THEME_COLORS array
THEME_COLORS=(
  # Core System Colors
  [none]="NONE"
  
  # Background Colors (Storm variant - slightly lighter)
  [background]="#24283b"           # Main background (lighter than night)
  [background-darker]="#1f2335"    # Darker background variant
  [surface]="#292e42"              # Surface/card background
  [overlay]="#3b4261"              # Overlay/modal background
  
  # Text Colors (same as night)
  [text]="#c0caf5"                 # Primary text
  [text-secondary]="#a9b1d6"       # Secondary text
  [text-muted]="#565f89"           # Muted/comment text
  [text-disabled]="#414868"        # Disabled text
  
  # Border Colors
  [border]="#3b4261"               # Default border
  [border-light]="#545c7e"         # Light border
  [border-strong]="#737aa2"        # Strong border
  
  # Semantic Colors (Primary Actions)
  [primary]="#7aa2f7"              # Primary blue
  [primary-darker]="#3d59a1"       # Darker primary
  [primary-lighter]="#89ddff"      # Lighter primary
  [accent]="#bb9af7"               # Accent purple/magenta
  [secondary]="#394b70"            # Secondary blue-gray
  
  # Status Colors
  [success]="#9ece6a"              # Success green
  [success-subtle]="#73daca"       # Subtle success
  [warning]="#e0af68"              # Warning yellow
  [warning-strong]="#ff9e64"       # Strong warning (orange)
  [error]="#f7768e"                # Error red
  [error-strong]="#db4b4b"         # Strong error
  [info]="#7dcfff"                 # Info cyan
  [info-subtle]="#2ac3de"          # Subtle info
  
  # Interactive States
  [hover]="#292e42"                # Hover state
  [active]="#3d59a1"               # Active state  
  [focus]="#7aa2f7"                # Focus state
  [disabled]="#565f89"             # Disabled state
  
  # Special Purpose
  [emphasis]="#ffffff"             # Maximum emphasis/white
  [subtle]="#545c7e"               # Subtle emphasis
  [muted]="#565f89"                # Muted/de-emphasized
  

)

export THEME_COLORS