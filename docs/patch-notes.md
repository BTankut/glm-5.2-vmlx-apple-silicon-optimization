# Patch Notes

This repository does not vendor full vMLX or `mlx-lm` source files. The notes below describe the local changes used in the validated setup.

## 1. GLM-5.2 DSA Indexer Sharing

The bundled `mlx_lm/models/glm_moe_dsa.py` was replaced with the GLM-5.2 DSA indexer-sharing implementation from upstream `mlx-lm` work.

Purpose:

- Fix GLM-5.2-specific model execution issues.
- Match the expected DSA full-indexer/shared-layer schedule.

Validated hash:

```text
61d51c5579da720ff11de48888e16861ab2171fbf33779d1809ab1820c3166b0
```

## 2. Sampling Guard and Bypass

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

