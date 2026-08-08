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

## 2026-08-09

- Audited the June profile against the current ecosystem and the original
  test workstation.
- Found the vMLX app had auto-updated itself to 1.5.69 and refreshed its
  bundled engine, silently reverting every in-bundle hand patch from this
  runbook (model file, wheel swap, seed patch). Documented as the primary
  operational hazard; recommended `pip install vmlx` for patched engines.
- Upstream sweep: `mlx-lm` still has no released GLM-5.2 IndexShare support
  (issue #1418 open; PRs #1410/#1412/#1419/#1463 open; latest release v0.31.3
  from April). The DSA model-file patch is therefore still required, and the
  right file to patch is `deepseek_v32.py` (the `glm_moe_dsa.py` shim contains
  no indexer code).
- vMLX 1.6.x superseded two patches: request-level seed landed in v1.6.6;
  the macOS-26 Metal issue is addressed by the separate Tahoe DMG shipped
  since v1.6.21/1.6.22 (root cause most plausibly mlx PR #3501, in 0.32.0).
- Noted 1.6.x behavior changes for clients: `reasoning_effort` implies
  thinking on (v1.6.6) and reasoning defaults to on (v1.6.7).
- LM Studio 0.4.20 re-checked: MLX engine pins a June-12 `mlx-lm` commit,
  GLM-5.2 load failure unchanged.
- Re-validation of the full profile on vMLX 1.6.x is pending (weights were
  not staged on the workstation at audit time).
