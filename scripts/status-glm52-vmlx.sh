#!/bin/zsh
set -euo pipefail

HEALTH_URL="${VMLINUX_HEALTH_URL:-http://127.0.0.1:8001/health}"
LOG_FILE="${VMLINUX_LOG_FILE:-/tmp/vmlx-glm52.err.log}"

echo "Process:"
pgrep -af "vmlx_engine.cli serve .*/GLM-5.2-mxfp4" || true

echo
echo "Listening sockets:"
lsof -nP -iTCP:8001 -sTCP:LISTEN 2>/dev/null || true

echo
echo "Health:"
if curl -fsS --max-time 5 "$HEALTH_URL" > /tmp/vmlx-glm52-health.json 2>/dev/null; then
  python3 -m json.tool /tmp/vmlx-glm52-health.json | sed -n '1,120p'
else
  echo "No server responding at $HEALTH_URL"
fi

echo
echo "Recent logs:"
tail -n 60 "$LOG_FILE" 2>/dev/null || true

