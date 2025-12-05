#!/usr/bin/env bash

# Tokyo Night Theme - PowerKit Semantic Color Mapping
# This file maps Tokyo Night colors to universal PowerKit semantic names
# that can be used across different themes consistently.

# Populate the global THEME_COLORS array for PowerKit compatibility
declare -A THEME_COLORS=(
  # Core System Colors
  [transparent]="NONE"
  [none]="NONE"
  
  # Background Colors
  [background]="#1a1b26"           # Main background
  [background-alt]="#16161e"       # Alternative/darker background
  [surface]="#292e42"              # Surface/card background
  [overlay]="#3b4261"              # Overlay/modal background
  
  # Text Colors  
  [text]="#ffffff"                 # Primary text
  [text-muted]="#565f89"           # Muted/comment text
  [text-disabled]="#414868"        # Disabled text
  
  # Border Colors
  [border]="#3b4261"               # Default border
  [border-subtle]="#545c7e"        # Subtle border
  [border-strong]="#737aa2"        # Strong border
  
  # Semantic Colors (PowerKit Standard)
  [accent]="#bb9af7"               # Main accent color (magenta)
  [primary]="#9d7cd8"              # Primary brand color (blue)
  [secondary]="#394b70"            # Secondary color (blue-gray)
  
  # Status Colors (PowerKit Standard)
  [success]="#9ece6a"              # Success state (green)
  [warning]="#e0af68"              # Warning state (yellow)
  [error]="#f7768e"                # Error state (red)
  [info]="#7dcfff"                 # Informational state (cyan)
  
  # Interactive States
  [hover]="#292e42"                # Hover state
  [active]="#3d59a1"               # Active state  
  [focus]="#7aa2f7"                # Focus state
  [disabled]="#565f89"             # Disabled state
  
  # Additional Variants
  [success-subtle]="#73daca"       # Subtle success
  [warning-strong]="#ff9e64"       # Strong warning (orange)
  [error-strong]="#db4b4b"         # Strong error
  [info-subtle]="#2ac3de"          # Subtle info
  
  # System Colors
  [white]="#ffffff"                # Pure white
  [black]="#000000"                # Pure black
)

# Export for PowerKit compatibility
export THEME_COLORS