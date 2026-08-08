# Validated Profile

> Validated on the vMLX 1.5.x app (June 2026). Two of the three hand patches
> are obsolete on current vMLX and one is still required — see the status
> section in the repository README before applying anything here.

## Model

- Hugging Face model: `mlx-community/GLM-5.2-mxfp4`
- Architecture: `GlmMoeDsaForCausalLM`
- Model type: `glm_moe_dsa`
- Quantization: 4-bit MXFP4
- Group size: `32`
- Hidden size: `6144`
- Layers: `78`
- Attention heads: `64`
- KV heads: `64`
- Vocab size: `154880`
- Max position embeddings: `1048576`
- Routed experts: `256`
- Active experts per token: `8`

## Runtime

- Runtime: vMLX
- Engine: `simple`
- Bind: `0.0.0.0`
- Port: `8001`
- Timeout: `3600`
- Default output limit: `16384`
- Prompt/context limit: `1048576`
- Stream interval: `4`

## Environment

```bash
MLX_METAL_FAST_SYNCH=1
PYTHONUNBUFFERED=1
VMLINUX_STREAM_VIA_GENERATE=0
VMLINUX_SYNC_GENERATE=0
VMLINUX_ALLOW_GLM52_SAMPLING=1
```

## Serve Arguments

```bash
--host 0.0.0.0
--port 8001
--timeout 3600
--max-tokens 16384
--max-prompt-tokens 1048576
--max-num-seqs 1
--prefill-batch-size 512
--prefill-step-size 2048
--completion-batch-size 512
--no-continuous-batching
--disable-prefix-cache
--kv-cache-quantization none
--tool-call-parser glm47
--enable-auto-tool-choice
--reasoning-parser deepseek_r1
--default-enable-thinking true
--stream-interval 4
--log-level INFO
```

## Current Hashes From the Validated Local Setup

These hashes are included to identify the exact local files after patching.

| File | SHA256 |
|---|---|
| `mlx_lm/models/glm_moe_dsa.py` | `61d51c5579da720ff11de48888e16861ab2171fbf33779d1809ab1820c3166b0` |
| `vmlx_engine/models/llm.py` | `7a19b319ef803a860eaf5238843d1b1f486ea20e2313863fc0c9592c9f22eee8` |
| `vmlx_engine/server.py` | `ba8957a08647c6ec8e5bc4a396e6f2587aee2e5dfc52f09ad7db9fe0058b5010` |
| `vmlx_engine/api/models.py` | `de9e30a2cf6c0c8787cc7c30d25897ef25d378bee42d52811100c8b6d90db437` |
| `vmlx_engine/api/ollama_adapter.py` | `1a0b45f6144e948cc34b9b44a06682dd3e449cf06ae88e17b6350885504d5db6` |

