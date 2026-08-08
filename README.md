# GLM-5.2 (744B) on 4× NVIDIA DGX Spark — Serving Recipe & Backend

Production notes for serving **GLM-5.2 744B** (QuantTrio Int4-Int8Mix checkpoint)
with **vLLM, tensor-parallel across four DGX Spark (GB10) nodes**, plus the
single-API backend built on top of it. Everything here is measured on real
hardware; every tuning claim carries its A/B numbers.

> This repository previously documented an early Apple-Silicon MLX experiment.
> That content is retired (still in git history); as of 2026-08-09 the repo
> tracks the actual production system.

## Headline numbers (measured)

| metric | value |
|---|---|
| Context window | **380,000 tokens** (+90% vs. the fp8-KV baseline, same speed) |
| Decode throughput | **~31 tok/s** median (MTP speculative decoding, accept ≈ 3.77) |
| Prefill throughput | ~322 tok/s at 346K depth (batched-tokens 4096) |
| Needle-in-haystack | **40/40** — 5–8 lengths × 5 depths, 5 code distractors per haystack, zero misses incl. 375K |
| Quality bench | 8/8 across the quant ladder |
| Vision | **full image input on a text-only model** — gateway bridge to a dedicated VLM; beat an in-model vision graft in an A/B *and* paid for +64K of context |

## Hardware

- 4 × DGX Spark: GB10 (Blackwell, `sm_121a`, aarch64), 128 GB unified
  LPDDR5X per node (121.7 GiB visible)
- Dual 200 Gb/s RoCE per node behind a MikroTik CRS812 switch; NCCL runs on a
  dedicated RoCE port (`NCCL_IB_HCA` / `NCCL_SOCKET_IFNAME` pinned, GID
  index for RoCEv2)
- TP=4: with MLA the KV latent is **replicated** across ranks — extra nodes
  shard the *weights*, and every freed byte funds the replicated KV pool

## The five decisions that matter

1. **KV cache: `nvfp4_ds_mla` + an explicitly pinned pool**
   (`--kv-cache-memory-bytes`). Pinning the KV pool is what makes 380K
   reproducible boot-to-boot; without it the pool drifts ±11–16% per boot.
2. **CUDA-graph capture sizes fitted to the real decode shapes.** With
   `max-num-seqs 3` and MTP k=4, every decode step is `num_seqs × (1+k)` =
   5, 10 or 15 tokens. vLLM's stock ladder `[1,2,4,8,16,24]` pads 5→8 (60%
   waste on the most common single-request case) and collides 10 and 15 into
   16. Fitting `cudagraph_capture_sizes:[5,10,15]` was a single-variable A/B:
   **28.6 → 31.0 tok/s (+8.4%)** for 30 MB of graph pool. Rule: capture sizes
   must be multiples of `(1 + num_speculative_tokens)` covering
   `1..max_num_seqs`.
3. **MTP speculative decoding** (`method:"mtp"`,
   `num_speculative_tokens:4`, `FLASHMLA_SPARSE` attention for the draft) —
   accept length ≈ 3.77.
4. **`--max-num-batched-tokens` follows your workload's prefill:decode
   ratio.** Measured break-even ≈ 7:1. A real agentic session measured
   **192:1** (3.2M prompt tokens vs 16.6K generated), so 4096 wins there
   (+11–15% prefill, −0..6% decode); decode-dominated chat prefers 2048.
   Both A/Bs are in [docs/serving.md](docs/serving.md).
5. **Vision lives outside the model — and that is a feature.** The
   production checkpoint is text-only; the gateway intercepts image parts on
   both API surfaces and a dedicated VLM (Qwen3-VL-30B-A3B) transcribes them
   under a strict character-exact prompt before the 744B ever sees the
   message. An A/B against an in-model vision graft favored the bridge on
   answer quality, and retiring the graft converted its memory into **+64K
   context (316K → 380K)**. Every client gets image input with zero
   configuration. Full design, the transcription-prompt rules and honest
   limits: [docs/vision.md](docs/vision.md).

## Quick recipe

```bash
./preflight.sh          # refuses a dirty boot: mem free, GPU held, containers
PHASE=3 ./launch.sh     # workers headless first, head last; ~10–22 min to serve
curl -s localhost:8210/v1/models   # expect max_model_len 380000
```

Full flags, fabric env, and the multi-node docker pattern:
[docs/serving.md](docs/serving.md).
GB10-specific operational pitfalls (read before first boot):
[docs/gb10-notes.md](docs/gb10-notes.md).
Vision on a text-only model (the bridge architecture):
[docs/vision.md](docs/vision.md).
The single-API backend (tool plane, hybrid streaming, job pattern):
[docs/backend.md](docs/backend.md).

## Why these nodes and not one big GPU

A 744B model at ~4-bit needs ~380 GB of weights plus KV. Four 128 GB
unified-memory nodes carry it at TP=4 with headroom for a 380K-token KV pool —
at desktop power draw. The tradeoff is interconnect: RoCE keeps TP viable, but
prefill is minutes at full depth, which shapes everything else (prefix caching
always on, agent loops replay history so only new tool results prefill).
