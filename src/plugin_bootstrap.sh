#!/usr/bin/env bash
# =============================================================================
# Plugin Bootstrap
# =============================================================================
# Single-source file that loads all common dependencies for plugins.
# This eliminates the need for each plugin to individually source 4 files.
#
# Usage in plugins:
#   ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
#   . "$ROOT_DIR/../plugin_bootstrap.sh"
#
# This file loads:
#   - defaults.sh    (configuration defaults)
#   - utils.sh       (utility functions)
#   - cache.sh       (caching system)
#   - plugin_helpers.sh (plugin helper functions)
#
# All files have source guards, so multiple includes are safe and fast.
# =============================================================================

# Source guard
if [[ -n "${_PLUGIN_BOOTSTRAP_LOADED:-}" ]]; then
    return 0 2>/dev/null || true
fi
_PLUGIN_BOOTSTRAP_LOADED=1

# Determine script directory
_BOOTSTRAP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Load all common dependencies (each has its own source guard)
# shellcheck source=src/defaults.sh
. "$_BOOTSTRAP_DIR/defaults.sh"
# shellcheck source=src/utils.sh
. "$_BOOTSTRAP_DIR/utils.sh"
# shellcheck source=src/cache.sh
. "$_BOOTSTRAP_DIR/cache.sh"
# shellcheck source=src/plugin_helpers.sh
. "$_BOOTSTRAP_DIR/plugin_helpers.sh"
