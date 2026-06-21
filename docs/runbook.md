# Runbook

## 1. Install vMLX

Install vMLX as a macOS application. This runbook assumes the bundled Python runtime exists at:

```text
/Applications/vMLX.app/Contents/Resources/bundled-python/python/bin/python
```

Adjust paths if your vMLX installation differs.

## 2. Download the Model

Use Hugging Face tooling or vMLX's built-in model flow to download:

```text
mlx-community/GLM-5.2-mxfp4
```

Example model path:

```text
$HOME/.cache/huggingface/hub/mlx-community/GLM-5.2-mxfp4
```

## 3. Apply Required Runtime Fixes

The validated setup used these local fixes:

1. GLM-5.2 DSA indexer-sharing implementation from upstream `mlx-lm`.
2. macOS 26 `mlx-metal` wheel for the installed MLX version.
3. Optional GLM-5.2 sampling guard with `VMLINUX_ALLOW_GLM52_SAMPLING=1`.
4. Request-level `seed` forwarding and `mlx.core.random.seed()` application.

See `docs/patch-notes.md`.

## 4. Install the LaunchAgent

Copy and edit:

```bash
cp configs/launchagent.example.plist "$HOME/Library/LaunchAgents/com.example.vmlx-glm52.plist"
```

Replace:

- `/ABS/PATH/TO/GLM-5.2-mxfp4`
- `/ABS/PATH/TO/WORKDIR`
- the label if desired

Then start:

```bash
launchctl bootstrap "gui/$(id -u)" "$HOME/Library/LaunchAgents/com.example.vmlx-glm52.plist"
launchctl kickstart -k "gui/$(id -u)/com.example.vmlx-glm52"
```

## 5. Verify Health

```bash
curl -sS http://127.0.0.1:8001/health | python3 -m json.tool
```

Expected highlights:

```json
{
  "status": "healthy",
  "model_name": "mlx-community/GLM-5.2-mxfp4",
  "engine_type": "simple",
  "max_prompt_tokens": 1048576
}
```

## 6. Verify OpenAI-Compatible API

```bash
curl -sS http://127.0.0.1:8001/v1/models | python3 -m json.tool
```

Smoke test:

```bash
python3 scripts/smoke-test-chat.py --base-url http://127.0.0.1:8001/v1
```

## 7. LAN Access

Find the Mac LAN IP:

```bash
ipconfig getifaddr en0
```

Use this base URL from another device on the same network:

```text
http://<mac-lan-ip>:8001/v1
```

## 8. Mobile Client Notes

Use conservative defaults first:

```json
{
  "temperature": 1.0,
  "top_p": 0.95,
  "max_tokens": 2048,
  "stream": true,
  "enable_thinking": false
}
```

If the client drops streaming connections, retry with:

```json
{
  "stream": false,
  "max_tokens": 2048,
  "enable_thinking": false
}
```

## 9. Stop

```bash
scripts/stop-glm52-vmlx.sh
```

