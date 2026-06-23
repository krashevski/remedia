#!/usr/bin/env bash
# modules/mediasystem/config/config.sh

# PATTERN: environment configuration (env-style config)
# PATTERN: feature flags (static configuration layer)

# ROLE:
# Provides static configuration for modules and policy engine.
# Does NOT contain logic.

# RULES:
# - no execution logic
# - no conditionals
# - only variable definitions

# NEVER EXECUTE DIRECTLY
# ONLY SOURCE

set -euo pipefail

SAFE_MODE="${SAFE_MODE:-1}"
ENABLE_CUDA="${ENABLE_CUDA:-n}"
