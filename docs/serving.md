# Serving GLM-5.2 744B with vLLM on 4× DGX Spark (TP=4)

Checkpoint: **QuantTrio GLM-5.2 Int4-Int8Mix** (weights Int4 with Int8-mix
sensitive layers), served text-only. All numbers measured on GB10
(`sm_121a`, aarch64, CUDA 13).

## The serve command (head node; workers identical + `--headless`)

```bash
vllm serve /path/to/glm52-int4-int8mix \
  --served-model-name glm-5.2 --host 0.0.0.0 --port 8210 \
  --trust-remote-code \
  --reasoning-parser glm45 --tool-call-parser glm47 --enable-auto-tool-choice \
  --enable-prefix-caching \
  --async-scheduling \
  --speculative-config '{"method":"mtp","num_speculative_tokens":4,"draft_tensor_parallel_size":1,"attention_backend":"FLASHMLA_SPARSE"}' \
  --model-loader-extra-config '{"enable_weights_track": true}' \
  --tensor-parallel-size 4 --pipeline-parallel-size 1 \
  --max-model-len 380000 \
  --max-num-seqs 3 --max-num-batched-tokens 4096 \
  --gpu-memory-utilization 0.91 --kv-cache-memory-bytes 13300000000 \
  --kv-cache-dtype nvfp4_ds_mla \
  --distributed-executor-backend mp \
  --compilation-config '{"cudagraph_mode":"FULL","cudagraph_capture_sizes":[5,10,15],"pass_config":{"fuse_allreduce_rms":true,"fuse_gemm_comms":true}}'
```

Multi-node pattern: start **workers first, headless**, head **last** —
dropping `--headless` on a follower costs a
`collective_rpc should not be called on follower node` and a 30-minute hang.

## RoCE fabric env (per container)

```bash
NCCL_NET=IB
NCCL_IB_DISABLE=0
NCCL_IB_HCA=mlx5_1            # your RoCE HCA (mlx5_X — check `ibv_devices`)
NCCL_SOCKET_IFNAME=<fabric-if> # the RoCE port's netdev
GLOO_SOCKET_IFNAME=<fabric-if>
NCCL_IB_GID_INDEX=3           # RoCEv2 GID — verify with `show_gids`
```

Run NCCL on a **dedicated** RoCE port if you have two; keeping ssh/docker
traffic off the fabric removes one whole class of jitter.

## Measured tuning A/Bs

### CUDA-graph capture sizes (+8.4%)

Decode steps are `max_num_seqs × (1 + MTP k)` tokens → 5/10/15 here. Stock
ladder `[1,2,4,8,16,24]` pads 5→8 and collides 10,15→16 (the boot log shows
`Capturing CUDA graphs (decode, FULL): 2/2` when three shapes exist).

| capture sizes | shapes | median tok/s | MTP accept |
|---|---|---|---|
| `[1,2,4,8,16,24]` (stock) | 2/2 | 28.6 | 3.73 |
| **`[5,10,15]` (fitted)** | **3/3** | **31.0** | 3.77 |

Also refuted the first hypothesis: the slowdown at 380K was not the longer
block table — it was this padding.

### `--max-num-batched-tokens` 2048 vs 4096

| setting | decode | prefill @310K | prefill @375K |
|---|---|---|---|
| 2048 | 31.0 tok/s | 322 tok/s | 275 tok/s |
| 4096 | 29.0 tok/s | 358 tok/s | 317 tok/s |

Accept length moved with it (3.77→3.70) — a real effect, not noise: the
sparse indexer's `expanded_block_table_buffer` is sized
`batched_tokens × blocks_per_req` and doubles. **Break-even ≈ 7:1
prefill:decode.** A real agentic workload measured **192:1** (3.2M prompt
tokens vs 16.6K generated in one session), which is why 4096 is the default
here; pick 2048 for decode-dominated chat. A later fresh-boot re-check at
4096: KV 385,375 tokens and 380K context unchanged, decode 31.2 vs 31.5,
prefill +11% vs interpolated 2048.

### KV ladder (same model, three configs)

| | fp8 KV, 200K | nvfp4 KV + vision graft, 316K | **nvfp4 KV text-only, 380K** |
|---|---|---|---|
| median tok/s | 31.1 | 30.9 | **31.0** |
| MTP accept | 3.74 | 3.83 | 3.77 |
| quality bench | 8/8 | 8/8 | 8/8 |
| needle grid | 25/25 | 35/35 | **40/40** |

`nvfp4_ds_mla` KV bought +90% context over fp8 KV at identical speed and
clean retrieval to 375K. **Pin the KV pool** (`--kv-cache-memory-bytes`):
unpinned, the pool drifts ±11–16% between boots and your context ceiling
drifts with it.

## Preflight (refuse a dirty boot)

A TP=4 boot costs 10–22 minutes; every failed boot we hit had a cause visible
in one second beforehand. Gate on three checks per node and refuse to launch
otherwise:

- `MemAvailable` above ~100 GiB
- GPU memory **held** below ~2 GiB (a zombie engine holds tens of GiB;
  process count is the wrong metric)
- zero running containers

See [gb10-notes.md](gb10-notes.md) for why the memory check fails after any
previous engine shutdown and what to do about it.
