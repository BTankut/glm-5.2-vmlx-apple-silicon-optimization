# Known Issues

## App Auto-Update Silently Reverts In-Bundle Patches

The vMLX Electron app auto-updates itself and refreshes its bundled Python
engine on startup. Every hand patch inside `/Applications/vMLX.app` (replaced
model file, swapped `mlx-metal` wheel, seed patch) is silently reverted by the
next update — observed directly on the test workstation, which had moved to
1.5.69 on its own with all patches gone.

Mitigation: run patched engines from a Python environment you control
(`pip install vmlx` / `uv tool install vmlx`, then `vmlx serve ...`). Treat
the app bundle as unpatchable.

## Request-Level Seed (historical)

Resolved upstream in vMLX v1.6.6 (2026-07-10): chat/completions honor a
request-local `seed`. The local patch in this runbook is only needed on 1.5.x.

## `Ollama is running` in the Browser

The root route on port `8001` may return:

```text
Ollama is running
```

This is expected. Port `8001` is an API server, not a browser chat UI.

Use:

```text
http://<mac-lan-ip>:8001/v1
```

from an OpenAI-compatible client.

## Client Timeout While Backend Keeps Generating

The vMLX simple engine uses a single generation lock. If a client disconnects during a long non-streaming request, the backend can continue generating and subsequent requests may appear to timeout.

Mitigation:

- Use streaming if the client supports it reliably.
- Keep mobile `max_tokens` at `2048` first.
- Avoid thinking mode for routine mobile chat.
- If a request gets stuck, use the request id from logs with:

```bash
curl -X POST http://127.0.0.1:8001/v1/chat/completions/<request-id>/cancel
```

## Reasoning Fields Sent Despite Thinking Off

Some clients may send `reasoning_effort` or `thinking_budget` even when `enable_thinking=false`.

Watch for log lines like:

```text
reasoning_effort='medium'
thinking_budget=8192
```

Remove those client-side custom parameters unless intentionally testing reasoning mode.

## `fence_update` Metal Failure

Earlier non-greedy sampling hit:

```text
RuntimeError: [metal::Device] Unable to load kernel fence_update
```

The validated setup fixed this by installing the macOS 26 `mlx-metal` wheel for the same MLX version and re-signing the affected binaries/application.

If this returns, remove:

```bash
VMLINUX_ALLOW_GLM52_SAMPLING=1
```

and fall back to greedy decoding until the Metal stack is fixed.

## 1M Context Is Admission, Not Free Speed

`--max-prompt-tokens 1048576` allows very large prompts, but long-context prefill is expensive. Do not use 1M context by default for mobile chat.

## Disabled Features in the Validated Profile

The stable profile disables:

- Continuous batching.
- Prefix cache.
- KV-cache quantization.
- Flash MoE experiments.

These may be revisited later, but were not included in the stable Apple Silicon/vMLX profile.

## LM Studio MLX Is Not Yet a Drop-In Replacement

LM Studio MLX 1.9.0 can discover `mlx-community/GLM-5.2-mxfp4`, but the tested load path fails with:

```text
ValueError: Missing 285 parameters: model.layers.*.self_attn.indexer.*
```

Treat LM Studio as not validated for this exact GLM-5.2 MXFP4 MLX model until its bundled MLX engine supports the required GLM-5.2 DSA indexer-sharing behavior. See `docs/lm-studio.md`.
