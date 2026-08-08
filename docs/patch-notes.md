# Patch Notes

This repository does not vendor full vMLX or `mlx-lm` source files. The notes below describe the local changes used in the validated setup.

## 1. GLM-5.2 DSA Indexer Sharing

**Status 2026-08-09: STILL REQUIRED.** No released `mlx-lm` (latest v0.31.3)
supports GLM-5.2 IndexShare; tracking `ml-explore/mlx-lm` issue #1418. Note
that upstream `glm_moe_dsa.py` is a thin shim — the indexer implementation
lives in `deepseek_v32.py`, so that is the file to inspect or replace.

The bundled `mlx_lm/models/glm_moe_dsa.py` was replaced with the GLM-5.2 DSA indexer-sharing implementation from upstream `mlx-lm` work.

Purpose:

- Fix GLM-5.2-specific model execution issues.
- Match the expected DSA full-indexer/shared-layer schedule.

Validated hash:

```text
61d51c5579da720ff11de48888e16861ab2171fbf33779d1809ab1820c3166b0
```

## 2. Sampling Guard and Bypass

**Status 2026-08-09:** still applies to 1.5.x-era bundles. On vMLX >= 1.6.21
install the Tahoe (macOS 26) DMG instead of swapping wheels (see patch 3).

A local GLM-5.2 guard was added around sampling. Without the bypass, GLM-5.2 MXFP4 requests can be forced to greedy decoding:

```text
temperature=0.0
top_p=1.0
top_k=0
min_p=0.0
```

After installing the macOS 26 `mlx-metal` wheel, sampling was enabled through:

```bash
VMLINUX_ALLOW_GLM52_SAMPLING=1
```

## 3. macOS 26 `mlx-metal` Wheel

**Status 2026-08-09: OBSOLETE on vMLX >= 1.6.21/1.6.22** — the app now ships a
separate Tahoe (macOS 26) build. Likely root cause of the original crash:
`ml-explore/mlx` PR #3501 (metallib deployment target), shipped in mlx 0.32.0
(our attribution, not an upstream statement).

The local vMLX bundle originally had `mlx-metal 0.31.2` from the `macosx_14_0_arm64` wheel. The validated setup installed the `macosx_26_0_arm64` wheel for the same version.

After replacing the wheel, the following were ad-hoc signed:

```text
mlx/lib/libmlx.dylib
mlx/lib/libjaccl.dylib
mlx/core.cpython-312-darwin.so
bundled python3.12
/Applications/vMLX.app
```

## 4. Request-Level Seed Support

vMLX's OpenAI-compatible path did not preserve `seed` end-to-end. The local patch added:

- `seed` to `ChatCompletionRequest`.
- `seed` to `CompletionRequest`.
- `seed` to `ResponsesRequest`.
- forwarding into server generation kwargs.
- forwarding from the Ollama-compatible adapter.
- `mlx.core.random.seed(seed)` before sampler creation in the language model wrapper.

Expected behavior:

- Same prompt + same settings + same seed should reproduce output.
- Different seeds should affect output when sampling entropy is high enough.

