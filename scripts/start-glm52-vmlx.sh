#!/bin/zsh
set -euo pipefail

LABEL="${VMLINUX_LAUNCHD_LABEL:-com.example.vmlx-glm52}"
PLIST="${VMLINUX_PLIST:-$HOME/Library/LaunchAgents/${LABEL}.plist}"
DOMAIN="gui/$(id -u)"
HEALTH_URL="${VMLINUX_HEALTH_URL:-http://127.0.0.1:8001/health}"

if [[ ! -f "$PLIST" ]]; then
  echo "Missing LaunchAgent: $PLIST" >&2
  echo "Copy configs/launchagent.example.plist and edit paths first." >&2
  exit 1
fi

launchctl bootout "$DOMAIN" "$PLIST" 2>/dev/null || true
pkill -f "vmlx_engine.cli serve .*/GLM-5.2-mxfp4" 2>/dev/null || true

launchctl bootstrap "$DOMAIN" "$PLIST"
launchctl kickstart -k "$DOMAIN/$LABEL"

echo "Starting GLM-5.2 MXFP4"
echo "Health: $HEALTH_URL"

for _ in {1..240}; do
  if curl -fsS --max-time 2 "$HEALTH_URL" > /tmp/vmlx-glm52-health.json 2>/dev/null; then
    status="$(python3 - <<'PY'
import json
try:
    data = json.load(open("/tmp/vmlx-glm52-health.json"))
    print(data.get("status", "unknown"))
except Exception:
    print("unknown")
PY
)"
    if [[ "$status" == "healthy" || "$status" == "standby_deep" ]]; then
      echo "Ready: $status"
      exit 0
    fi
  fi
  sleep 2
done

echo "Still starting. Check your vMLX logs."
exit 2

