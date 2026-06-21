# Patches

This directory intentionally does not include full vendored vMLX or `mlx-lm` source files.

Use `docs/patch-notes.md` as the implementation guide. The validated local setup used these patch categories:

1. GLM-5.2 DSA indexer-sharing update in `mlx_lm/models/glm_moe_dsa.py`.
2. GLM-5.2 sampling guard with `VMLINUX_ALLOW_GLM52_SAMPLING=1` bypass.
3. macOS 26 `mlx-metal` wheel replacement and ad-hoc signing.
4. Request-level seed support across vMLX API schemas, server forwarding, Ollama adapter forwarding, and MLX RNG application.

Recommended upstreaming path:

- Keep patches small and feature-scoped.
- Submit seed support separately from model/runtime-specific GLM-5.2 changes.
- Keep Metal wheel/signing notes as deployment documentation, not as an upstream code patch.

