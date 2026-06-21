#!/bin/zsh
set -euo pipefail

LABEL="${VMLINUX_LAUNCHD_LABEL:-com.example.vmlx-glm52}"
PLIST="${VMLINUX_PLIST:-$HOME/Library/LaunchAgents/${LABEL}.plist}"
DOMAIN="gui/$(id -u)"

launchctl bootout "$DOMAIN" "$PLIST" 2>/dev/null || true
pkill -f "vmlx_engine.cli serve .*/GLM-5.2-mxfp4" 2>/dev/null || true

echo "Stopped GLM-5.2 MXFP4 server."

