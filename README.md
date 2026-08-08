# GLM-5.2 vMLX Apple Silicon Optimization

Runbook and reproducible startup profile for serving **`mlx-community/GLM-5.2-mxfp4`** with **vMLX** on Apple Silicon.

> **Status update (2026-08-09).** The profile below was validated on the vMLX
> 1.5.x app (June 2026). The ecosystem has moved since — the app is at 1.6.25
> and two of the three hand patches documented here are now obsolete, while one
> is still required. See [Status: what changed since June](#status-what-changed-since-june-2026)
> before following the patch instructions.

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

## Status: what changed since June 2026

Audited 2026-08-09 against upstream (mlx / mlx-lm / vMLX / LM Studio releases)
and against the original test workstation.

### Patch status today

| June 2026 hand patch | Status on current stacks |
|---|---|
| **GLM-5.2 DSA indexer-sharing model file** | **STILL REQUIRED.** No released `mlx-lm` supports GLM-5.2 IndexShare (latest release is still v0.31.3, 2026-04-22). Tracking: `ml-explore/mlx-lm` issue #1418; candidate PRs #1410 / #1412 / #1419 / #1463 all open as of 2026-08-09. Note: upstream `glm_moe_dsa.py` is a thin shim over `deepseek_v32.py` — the indexer code lives in `deepseek_v32.py`, so inspect/patch there, not the shim. PR #1431 (interleaved indexer rope, needed by GLM-5.2) merged 2026-06-24 but is unreleased. |
| **Request-level `seed` patch in vMLX** | **OBSOLETE on vMLX ≥ 1.6.6** (2026-07-10): request-local seed on chat/completions landed upstream. Still needed only if you stay on 1.5.x. |
| **macOS 26 `mlx-metal` wheel swap** | **OBSOLETE on vMLX ≥ 1.6.21/1.6.22** (2026-08-02): the app now ships a separate **Tahoe (macOS 26) DMG** — install that build instead of swapping wheels. Root cause of the original `fence_update` sampling crash was most plausibly the metallib deployment-target defect fixed by `ml-explore/mlx` PR #3501 (in mlx 0.32.0); that attribution is our inference, not an upstream statement. |

### The most important operational lesson

**The vMLX Electron app auto-updates itself AND its bundled Python engine**
(release rollout is roughly five minutes; the updater also refreshes the
bundled engine on startup). Any hand patch inside `/Applications/vMLX.app` —
the replaced model file, the wheel swap, the seed patch — **is silently
reverted by the next update**. We hit exactly this: the app had moved to
1.5.69 on its own and every in-bundle patch from this runbook was gone.

The supported way to run a patched engine is to bypass the app bundle
entirely: the engine is open source (`pip install vmlx` / `uv tool install
vmlx`, same OpenAI/Anthropic/Ollama API via `vmlx serve`). Keep local patches
in a Python environment you control; use the app only as an unpatched
convenience.

### Other findings (2026-08-09)

- vMLX versions: 1.5.x ended at 1.5.69 (2026-06-23); 1.6.x is current
  (1.6.25, 2026-08-08). Engine repo: `github.com/jjang-ai/vmlx`; app DMGs:
  `github.com/jjang-ai/mlxstudio`; site: `vmlx.net`.
- Client-relevant 1.6.x behavior changes: since v1.6.6 a concrete
  `reasoning_effort` **implies thinking on**, and since v1.6.7 reasoning is
  **on by default** for reasoning-capable families. If you want thinking off,
  set `enable_thinking: false` explicitly and do not send `reasoning_effort`
  at all — this makes the client guidance below even more important.
- "vMLX v2 (beta)" is an experimental Swift-native rewrite that installs
  alongside v1. Its release track has been dormant since early May and GLM-5.2
  support on it is undocumented — stay on the Python/Electron v1 track for
  this model.
- Native MTP speculative decoding arrived in 1.6.x (depth autotuning in
  v1.6.6) — untested with GLM-5.2 here; a candidate for the next validation
  pass.
- LM Studio still cannot load this model: app 0.4.20 (2026-07-22); its MLX
  engine pins an `mlx-lm` commit from 2026-06-12, which predates all GLM-5.2
  IndexShare work, so the June failure mode is unchanged. See
  `docs/lm-studio.md`.
- **Re-validation pending:** the June profile has not yet been re-validated on
  vMLX 1.6.x (the test workstation no longer had the weights staged at audit
  time). Treat the validated profile as accurate for the June 1.5.x build and
  this section as the map of what to re-check.

## Validated Profile Status (June 2026)

- Stable LAN serving through the OpenAI-compatible API.
- 1M prompt limit configured and accepted by the runtime. Full 1M-token prefill is not a default operating mode and was not the throughput target.
- Sampling works after replacing the bundled macOS 14 `mlx-metal` wheel with the macOS 26 wheel for the same MLX version (see status above — obsolete on ≥1.6.21).
- Request-level seed is supported after a local vMLX patch (see status above — upstream on ≥1.6.6).
- Continuous batching, prefix cache, and KV-cache quantization are disabled in the validated profile for this specific model/runtime combination.
- LM Studio MLX 1.9.0 sees the model but fails to load it with a GLM-5.2 DSA indexer mismatch. See `docs/lm-studio.md`.

See `docs/runbook.md` and `docs/known-issues.md` for details.
