# Worklog

## 2026-06-20

- Started from a local vMLX GLM-5.2 MXFP4 server.
- Confirmed model metadata, 1M max position embeddings, and MXFP4 affine quantized matmul path.
- Added a LaunchAgent-managed startup profile.
- Bound the server to `0.0.0.0:8001` for LAN access.
- Verified `/health` and `/v1/models`.

## 2026-06-21

- Replaced the bundled `mlx_lm/models/glm_moe_dsa.py` with the upstream GLM-5.2 DSA indexer-sharing implementation.
- Added a GLM-5.2 sampling guard and an environment override.
- Replaced bundled `mlx-metal 0.31.2` from the macOS 14 wheel with the macOS 26 wheel for the same version.
- Re-signed vMLX after modifying bundled Python and MLX files.
- Confirmed non-greedy sampling no longer hit the earlier `fence_update` failure.
- Patched request-level `seed` support through vMLX's OpenAI-compatible API models, server routing, and MLX generation wrapper.
- Verified same seed reproduces identical output and different seeds produce different output with active sampling settings.
- Tested LAN clients and documented safe iPad/mobile configuration.
- Tested LM Studio MLX 1.9.0 as an alternative server path. Discovery worked, but model load failed with a GLM-5.2 DSA indexer missing-parameters error.
