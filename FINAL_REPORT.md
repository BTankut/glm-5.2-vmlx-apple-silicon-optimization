# Final Report

## Summary

This repository documents a validated GLM-5.2 MXFP4 deployment profile for vMLX on Apple Silicon. The goal was not to maximize every benchmark knob, but to produce a stable local server that supports long context, LAN clients, sampling, tool/reasoning experiments, and reproducible request seeds.

## What Worked

- Serving `mlx-community/GLM-5.2-mxfp4` with vMLX simple engine.
- Binding the API to `0.0.0.0:8001` for LAN clients.
- Setting `--max-prompt-tokens 1048576` for 1M prompt admission.
- Using real streaming after earlier fallback experiments were removed.
- Enabling sampling after installing the macOS 26 `mlx-metal` wheel.
- Preserving `seed` across OpenAI-compatible and Ollama-compatible request paths after patching vMLX.
- Using mobile clients with OpenAI-compatible base URL `http://<mac-lan-ip>:8001/v1`.

## What Did Not Work

- LM Studio MLX 1.9.0 detected `mlx-community/GLM-5.2-mxfp4` as `glm_moe_dsa`, but failed to load it with `ValueError: Missing 285 parameters: model.layers.*.self_attn.indexer.*`.
- The vMLX menu/session path did not reliably apply the custom long-context and GLM-5.2-specific settings. The reproducible route is the script/LaunchAgent profile in this repository.

## Practical Performance

Observed generation speed on longer responses was roughly `12-20 tok/s`. Short responses are dominated by TTFT and are not useful for throughput comparison.

## Important Tradeoffs

The validated profile keeps these features disabled:

- Continuous batching.
- Prefix cache.
- KV-cache quantization.
- Flash MoE experiments.

These features may be useful later, but they were not part of the stable local vMLX profile captured here.

## Most Important Operational Lesson

Mobile clients may timeout while the backend continues generating. With the vMLX simple engine, a long generation can hold the single generation lock and make subsequent calls appear to timeout. Use conservative mobile settings first:

```json
{
  "temperature": 1.0,
  "top_p": 0.95,
  "max_tokens": 2048,
  "stream": true,
  "enable_thinking": false
}
```

Avoid sending hidden reasoning fields such as `reasoning_effort` or `thinking_budget` unless you intentionally want a long reasoning run.

## Addendum (2026-08-09)

The report above describes the June 2026 state. An August audit found:

- The app auto-update had reverted all in-bundle patches (see README status
  section). Run patched engines from a pip/uv environment, not the app bundle.
- Still required: the GLM-5.2 DSA indexer model-file patch (no released
  `mlx-lm` supports IndexShare yet; patch `deepseek_v32.py`).
- No longer required on current vMLX: the seed patch (upstream in v1.6.6) and
  the mlx-metal wheel swap (use the Tahoe DMG shipped since v1.6.21/1.6.22).
- LM Studio (0.4.20) still cannot load the model.
- The profile awaits re-validation on vMLX 1.6.x.
