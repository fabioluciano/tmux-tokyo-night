#!/usr/bin/env bash

# Tokyo Night Moon - Semantic Color Mapping

# Populate the global THEME_COLORS array
THEME_COLORS=(
  # Core System Colors
  [none]="NONE"
  
  # Background Colors (Moon variant - balanced)
  [background]="#222436"           # Main background
  [background-darker]="#1e2030"    # Darker background variant
  [surface]="#2f334d"              # Surface/card background
  [overlay]="#3b4261"              # Overlay/modal background
  
  # Text Colors (Moon specific)
  [text]="#c8d3f5"                 # Primary text (cooler tone)
  [text-secondary]="#828bb8"       # Secondary text
  [text-muted]="#7a88cf"           # Muted/comment text
  [text-disabled]="#444a73"        # Disabled text
  
  # Border Colors
  [border]="#3b4261"               # Default border
  [border-light]="#545c7e"         # Light border
  [border-strong]="#737aa2"        # Strong border
  
  # Semantic Colors (Primary Actions)
  [primary]="#82aaff"              # Primary blue (brighter in moon)
  [primary-darker]="#3e68d7"       # Darker primary
  [primary-lighter]="#89ddff"      # Lighter primary
  [accent]="#c099ff"               # Accent purple (softer in moon)
  [secondary]="#394b70"            # Secondary blue-gray
  
  # Status Colors
  [success]="#c3e88d"              # Success green (softer)
  [success-subtle]="#4fd6be"       # Subtle success (teal)
  [warning]="#ffc777"              # Warning yellow (warmer)
  [warning-strong]="#ff966c"       # Strong warning (orange)
  [error]="#ff757f"                # Error red (softer)
  [error-strong]="#c53b53"         # Strong error
  [info]="#86e1fc"                 # Info cyan (brighter)
  [info-subtle]="#65bcff"          # Subtle info
  
  # Interactive States
  [hover]="#2f334d"                # Hover state
  [active]="#3e68d7"               # Active state  
  [focus]="#82aaff"                # Focus state
  [disabled]="#7a88cf"             # Disabled state
  
  # Special Purpose
  [emphasis]="#ffffff"             # Maximum emphasis/white
  [subtle]="#545c7e"               # Subtle emphasis
  [muted]="#7a88cf"                # Muted/de-emphasized
  

)

export THEME_COLORS