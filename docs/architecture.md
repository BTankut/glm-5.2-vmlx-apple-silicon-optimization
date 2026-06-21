# Architecture

## Components

```text
OpenAI-compatible client
        |
        | HTTP /v1/chat/completions
        v
vMLX API server on macOS
        |
        | SimpleEngine
        v
MLX / mlx-lm runtime
        |
        v
mlx-community/GLM-5.2-mxfp4
```

## Runtime Shape

- vMLX serves the model through an OpenAI-compatible API.
- The server binds to `0.0.0.0:8001` for LAN clients.
- Health checks use `http://127.0.0.1:8001/health`.
- The simple engine runs one generation at a time.
- Mobile or LAN clients should treat the server as a single-user/high-memory local inference endpoint.

## Why Simple Engine

The validated path stayed with the vMLX simple engine because it was the most stable route for this model/runtime combination after the GLM-5.2 DSA and Metal fixes.

Continuous batching may be attractive for throughput, but it was not part of the stable local GLM-5.2 profile captured here.

