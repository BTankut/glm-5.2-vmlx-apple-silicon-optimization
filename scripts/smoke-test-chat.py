#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import time
import urllib.request


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--base-url", default="http://127.0.0.1:8001/v1")
    parser.add_argument("--model", default="mlx-community/GLM-5.2-mxfp4")
    parser.add_argument("--timeout", type=int, default=120)
    args = parser.parse_args()

    body = {
        "model": args.model,
        "messages": [{"role": "user", "content": "Reply with OK only."}],
        "temperature": 0,
        "top_p": 1,
        "max_tokens": 8,
        "stream": False,
        "enable_thinking": False,
    }

    req = urllib.request.Request(
        f"{args.base_url.rstrip('/')}/chat/completions",
        data=json.dumps(body).encode("utf-8"),
        headers={
            "Content-Type": "application/json",
            "Authorization": "Bearer sk-no-key",
        },
    )

    started = time.time()
    with urllib.request.urlopen(req, timeout=args.timeout) as response:
        payload = json.loads(response.read())
    elapsed = time.time() - started
    content = payload["choices"][0]["message"].get("content", "")
    usage = payload.get("usage", {})

    print(f"elapsed={elapsed:.2f}s")
    print(f"content={content!r}")
    print(f"usage={usage}")


if __name__ == "__main__":
    main()

