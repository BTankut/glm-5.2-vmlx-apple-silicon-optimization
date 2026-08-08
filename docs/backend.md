# The Single-API Backend

Goal: **every client — chat UI, coding agent, mobile — talks to one
OpenAI/Anthropic-compatible endpoint and gets the full capability set**
(server-side tools, image understanding, long-running jobs) with zero
client-side configuration. Like the big providers' APIs, but local.

## Architecture

```
clients ──► thin compat gateway ──► (flag off) ─────────► vLLM GLM-5.2
                 │                   untouched legacy path, byte-identical
                 │ (tool-enabled profiles, per-API-key)
                 └─► LiteLLM proxy ─┬─► vLLM GLM-5.2
                     (MCP registry  └─► FastMCP tool servers
                      + executor)        (infographics, web search, ...)
```

- **Thin gateway** (FastAPI): protocol quirks, the image→text **vision
  bridge** (see [vision.md](vision.md) — one of the system's signature
  capabilities), time-based SSE keepalive, API-key→profile mapping.
  Fail-safe rule: any tool-plane error falls open to the legacy path — a bug
  degrades to plain chat, never a dead request.
- **LiteLLM** (digest-pinned container): MCP server registry, per-virtual-key
  permissions, and the REST tool executor (`/mcp-rest/tools/call`).
- **FastMCP servers**: each local capability is a few dozen lines.

## Measured findings you will hit if you build this

1. **LiteLLM's MCP auto-execution intercepts ALL tool calls** — including the
   client's own function tools (it tries to execute them itself and feeds the
   error back). If your clients bring their own tools (coding agents do), do
   NOT use auto-exec. We run a uniform **manual-mode mini-loop in the
   gateway**: every tool call returns to the gateway, which routes by
   ownership — client-declared tools pass through untouched; injected MCP
   tools execute server-side and the loop continues.
2. **Streaming with tools:** MCP auto-exec + `stream:true` leaks the
   intermediate `tool_calls` turn to the client (open upstream issue; chat
   UIs render an empty message). Manual mode has no such problem: with a
   proper tool-call parser the northbound stream carries structured tool-call
   deltas, so the gateway can stream content/reasoning deltas to the client
   LIVE and hide only the tool turns behind keepalives.
3. **Per-key tool exposure needs care.** The embedding-based semantic tool
   filter is global-only (cannot be disabled per key), and neither the
   per-key tool-search flag nor the `x-mcp-servers` header narrows the
   chat-path expansion. What does work: **one MCP descriptor per server**
   (`litellm_proxy/mcp/<server>`) per profile.
4. **Schema fidelity:** the proxy strips `additionalProperties` from tool
   schemas in transit. Byte-diff what the model receives against what your
   MCP server declares; know your deltas.
5. **Long-running tools need a job pattern, not long HTTP calls.** Renders
   here take 5–25 minutes. The tool returns `{job_id}` in under 2 s; the
   GATEWAY owns waiting (polls status, streams progress, appends the artifact
   URL to the answer). Two extra guards proved necessary in production:
   - **Idempotency**: identical request within a window returns the existing
     job (an agent that lost its job id between turns re-rendered the same
     image three times before this).
   - **A poll brake**: models will happily busy-poll a running job inside one
     reply and burn the tool-turn budget. Second poll of a running job gets a
     "stop polling, finish your answer" instruction appended; a third forces
     finalization and hands the wait to the gateway driver.
6. **Client history never contains server-side tool exchanges** (clients
   replay their own view). Keep final answers self-contained and rely on
   idempotency — or budget for a server-side conversation store.

## Division of labor with the model server

The gateway/tool plane adds **zero load** to the inference cluster: rendering
runs on a separate workstation, web search hits a local metasearch engine,
and the vision bridge runs a small VLM elsewhere. The 4× DGX cluster does
exactly one thing: serve GLM-5.2.
