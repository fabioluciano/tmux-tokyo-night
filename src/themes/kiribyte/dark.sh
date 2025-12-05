#!/usr/bin/env bash
# Tokyo Night Pastel - Semantic Color Mapping
# Populate the global THEME_COLORS array

declare -A THEME_COLORS=(
    # Core System Colors
    [none]="NONE"
    
    # Background Colors (Pastel variant - softer and lighter)
    [background]="#2a2b3d"           # Main background (pastel base)
    [background-alt]="#252631"       # Alternative/darker background
    [background-darker]="#252631"    # Darker background variant
    ["surface"]="#3b3f5c"              # Surface/card background
    ["overlay"]="#4d5270"              # Overlay/modal background
    
    # Text Colors (softer, more pastel)
    ["text"]="#dce3ff"                 # Primary text (lighter, softer white)
    ["text-secondary"]="#a3a8c7"       # Secondary text (muted lavender)
    ["text-muted"]="#8a8fb5"           # Muted/comment text
    ["text-disabled"]="#6d7187"        # Disabled text
    
    # Border Colors
    ["border"]="#4d5270"               # Default border
    ["border-light"]="#8a91ad"         # Light border
    ["border-strong"]="#9ba3c4"        # Strong border
    
    # Semantic Colors (Primary Actions)
    ["primary"]="#a4c5ff"              # Primary blue (soft pastel blue)
    ["primary-darker"]="#6d85c4"       # Darker primary
    ["primary-lighter"]="#b8edff"      # Lighter primary (sky blue)
    ["accent"]="#d4c5ff"               # Accent purple (soft lavender)
    ["secondary"]="#687aa3"            # Secondary blue-gray
    
    # Status Colors
    [success]="#c7e8a8"              # Success green (mint pastel)
    [success-subtle]="#a8e8db"       # Subtle success (aqua pastel)
    [warning]="#f0d1a3"              # Warning yellow (cream pastel)
    [warning-strong]="#ffbfa0"       # Strong warning (peach pastel)
    [error]="#ff6b85"                # Error red (rose pastel)
    [error-strong]="#ff8fa3"         # Strong error (coral pastel)
    [info]="#ade5ff"                 # Info cyan (baby blue pastel)
    [info-subtle]="#7ddcf0"          # Subtle info (turquoise pastel)
    
    # Interactive States
    [hover]="#313342"                # Hover state
    [active]="#6d85c4"               # Active state (primary-darker)
    [focus]="#a4c5ff"                # Focus state (primary)
    [disabled]="#8a8fb5"             # Disabled state
    
    # Special Purpose
    [emphasis]="#ffffff"             # Maximum emphasis/white
    [subtle]="#8a91ad"               # Subtle emphasis
    [muted]="#8a8fb5"                # Muted/de-emphasized
)

export THEME_COLORS