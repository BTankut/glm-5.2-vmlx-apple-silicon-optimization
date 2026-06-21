# GLM-5.2 vMLX Apple Silicon Optimization

Runbook and reproducible startup profile for serving **`mlx-community/GLM-5.2-mxfp4`** with **vMLX** on Apple Silicon.

This repository captures a working local inference setup for GLM-5.2 MXFP4 on a high-memory Apple Silicon workstation. It focuses on practical stability, LAN access, OpenAI-compatible clients, long-context configuration, and the fixes needed to make sampling and request-level seeds usable.

The validated path is **vMLX as the OpenAI-compatible server layer, backed by MLX / mlx-lm for inference**. LM Studio was tested separately and is documented as not validated for this exact GLM-5.2 MXFP4 MLX model.

## Project Purpose

Running GLM-5.2 MXFP4 through vMLX exposed several practical issues:

- GLM-5.2 required the newer DSA indexer-sharing implementation from upstream `mlx-lm`.
- Non-greedy sampling initially hit MLX Metal `fence_update` failures.
- vMLX's OpenAI-compatible layer did not preserve request-level `seed`.
- Some client apps sent conflicting reasoning fields even when thinking was intended to be off.
- Very large output budgets and thinking mode could keep the single simple-engine generation lock busy after a client timeout.

This repository documents the working profile and ships small helper scripts plus example configs.

## Validated Target

| Item | Value |
|---|---|
| Model | `mlx-community/GLM-5.2-mxfp4` |
| Runtime | vMLX |
| Engine | `simple` |
| Host binding | `0.0.0.0` for LAN access |
| API port | `8001` |
| Prompt/context limit | `1,048,576` tokens |
| Default output limit | `16,384` tokens |
| Practical client output limit | `2,048` to `4,096` tokens |
| Observed decode speed | about `12-20 tok/s` on longer outputs |
| Sampling | enabled after macOS 26 `mlx-metal` wheel replacement |
| Seed support | patched into vMLX's OpenAI-compatible routes |

## Repository Structure

```text
.
|-- README.md
|-- FINAL_REPORT.md
|-- WORKLOG.md
|-- configs/
|   |-- client-params.json
|   `-- launchagent.example.plist
|-- docs/
|   |-- architecture.md
|   |-- client-configuration.md
|   |-- lm-studio.md
|   |-- known-issues.md
|   |-- patch-notes.md
|   |-- runbook.md
|   `-- validated-profile.md
|-- patches/
|   `-- README.md
`-- scripts/
    |-- smoke-test-chat.py
    |-- start-glm52-vmlx.sh
    |-- status-glm52-vmlx.sh
    `-- stop-glm52-vmlx.sh
```

## Quick Start

Edit the paths in `configs/launchagent.example.plist` and install it as:

```bash
cp configs/launchagent.example.plist "$HOME/Library/LaunchAgents/com.example.vmlx-glm52.plist"
launchctl bootstrap "gui/$(id -u)" "$HOME/Library/LaunchAgents/com.example.vmlx-glm52.plist"
launchctl kickstart -k "gui/$(id -u)/com.example.vmlx-glm52"
```

Or run the helper scripts after setting the variables at the top of each script:

```bash
scripts/start-glm52-vmlx.sh
scripts/status-glm52-vmlx.sh
```

Health check:

```bash
curl -sS http://127.0.0.1:8001/health | python3 -m json.tool
```

OpenAI-compatible client base URL:

```text
http://<mac-lan-ip>:8001/v1
```

Model name:

```text
mlx-community/GLM-5.2-mxfp4
```

API key:

```text
sk-no-key
```

The server profile documented here does not require an API key. Add one before exposing the service beyond a trusted LAN.

## Recommended Client Parameters

For stable iPad/mobile clients:

```json
{
  "temperature": 1.0,
  "top_p": 0.95,
  "max_tokens": 2048,
  "stream": true,
  "enable_thinking": false
}
```

Increase `max_tokens` to `4096` only after the client is stable. Avoid sending `reasoning_effort`, `thinking_budget`, or nested reasoning options when `enable_thinking` is false.

## Current Status

- Stable LAN serving through the OpenAI-compatible API.
- 1M prompt limit configured and accepted by the runtime. Full 1M-token prefill is not a default operating mode and was not the throughput target.
- Sampling works after replacing the bundled macOS 14 `mlx-metal` wheel with the macOS 26 wheel for the same MLX version.
- Request-level seed is supported after a local vMLX patch.
- Continuous batching, prefix cache, and KV-cache quantization are disabled in the validated profile for this specific model/runtime combination.
- LM Studio MLX 1.9.0 sees the model but fails to load it with a GLM-5.2 DSA indexer mismatch. See `docs/lm-studio.md`.

See `docs/runbook.md` and `docs/known-issues.md` for details.
