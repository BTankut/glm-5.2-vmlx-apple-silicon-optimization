# LM Studio Compatibility Check

## Summary

LM Studio was tested as a possible alternative MLX server. The result was negative for this exact model/runtime combination.

Validated result:

- LM Studio app version observed locally: `0.4.17-beta+3`
- LM Studio MLX runtime: `mlx-llm-mac-arm64-apple-metal-advsimd@1.9.0`
- Model: `mlx-community/GLM-5.2-mxfp4`
- Format detected by LM Studio: `safetensors`
- Architecture detected by LM Studio: `glm_moe_dsa`
- Result: model discovery works, model load fails

## Discovery Behavior

LM Studio's staff-pick search did not return GLM-5.2:

```bash
lms get "glm-5.2" --mlx
```

Result:

```text
Error: No staff picks found with the specified search criteria.
```

Using the Hugging Face URL did resolve the model:

```bash
lms get "https://huggingface.co/mlx-community/GLM-5.2-mxfp4" --mlx
```

LM Studio identified:

```text
GLM 5.2 MXFP4 [MLX] - 395.11 GB
```

The download was not started during this test because the model already existed in the Hugging Face cache.

## Local Symlink Test

To avoid another 395 GB download, the existing Hugging Face cache directory was temporarily exposed to LM Studio's local model directory:

```bash
ln -s \
  "$HOME/.cache/huggingface/hub/mlx-community/GLM-5.2-mxfp4" \
  "$HOME/.lmstudio/models/mlx-community/GLM-5.2-mxfp4"
```

After rescanning, LM Studio listed:

```text
glm-5.2 | GLM 5.2 | safetensors | glm_moe_dsa | 395114851125
```

This only proved model discovery. It did not prove runtime compatibility.

## Load Estimate

```bash
lms load glm-5.2 --estimate-only --context-length 4096 --identifier glm52-lmstudio-test -y
```

Result:

```text
Model: glm-5.2
Context Length: 4,096
Estimated GPU Memory:   515.17 GiB
Estimated Total Memory: 515.17 GiB
Confidence: LOW
```

The estimate did not materially change for smaller context values, which suggests the estimate is dominated by model weight and loader overhead rather than KV-cache sizing.

## Real Load Result

```bash
lms load glm-5.2 --context-length 4096 --identifier glm52-lmstudio-test --ttl 900 -y
```

The loader progressed to roughly 67% and then failed:

```text
Error when loading model: ValueError: Missing 285 parameters:
model.layers.*.self_attn.indexer.*
```

The missing parameters are GLM-5.2 DSA indexer weights such as:

```text
self_attn.indexer.k_norm.bias
self_attn.indexer.k_norm.weight
self_attn.indexer.weights_proj.weight
self_attn.indexer.wk.weight
self_attn.indexer.wq_b.weight
```

## Conclusion

LM Studio MLX 1.9.0 can discover `mlx-community/GLM-5.2-mxfp4`, but it cannot load it correctly in this local test. The failure matches the GLM-5.2 DSA indexer-sharing area that required a patched `mlx_lm/models/glm_moe_dsa.py` in the validated vMLX setup.

For now, LM Studio should be documented as:

```text
not validated / currently failing for GLM-5.2 MXFP4 MLX
```

The working route in this repository remains vMLX plus the MLX/mlx-lm patches described in `docs/patch-notes.md`.
