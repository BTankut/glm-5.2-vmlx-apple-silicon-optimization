# Client Configuration

## OpenAI-Compatible Clients

Use:

```text
Provider: OpenAI Compatible / Custom OpenAI
Base URL: http://<mac-lan-ip>:8001/v1
API key: sk-no-key
Model: mlx-community/GLM-5.2-mxfp4
```

If the client allows an empty API key, an empty value may also work. Some clients require a placeholder, so `sk-no-key` is a safe dummy value when the server has no API-key enforcement.

## Recommended Request Body

```json
{
  "model": "mlx-community/GLM-5.2-mxfp4",
  "messages": [
    {
      "role": "user",
      "content": "Hello"
    }
  ],
  "temperature": 1.0,
  "top_p": 0.95,
  "max_tokens": 2048,
  "stream": true,
  "enable_thinking": false
}
```

## Parameters to Avoid Unless Needed

Do not send these when thinking is intended to be off:

```json
{
  "reasoning_effort": "medium",
  "chat_template_kwargs": {
    "reasoning_effort": "medium",
    "thinking_budget": 8192
  }
}
```

Some clients add these automatically. If the server log shows them despite `enable_thinking=false`, remove the related preset from the client.

## Timeout Guidance

Client-side timeout should be at least `120-300` seconds for mobile clients. Very long responses or thinking-mode runs may need more.

## Seed

After the seed patch, this works:

```json
{
  "seed": 123,
  "temperature": 1.8,
  "top_p": 1.0,
  "top_k": 50
}
```

Same prompt plus same sampling settings plus same seed should reproduce output. Low-entropy prompts can still produce the same output across different seeds.

