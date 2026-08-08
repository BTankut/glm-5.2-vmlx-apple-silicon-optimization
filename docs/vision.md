# Vision Without a Vision Model

The 744B production model is **deliberately text-only** — and the system still
takes images from every client, on both API surfaces, with zero client
configuration. This page explains the architecture and why it beat the
obvious alternative in an A/B.

## The design

```
client sends an image (OpenAI image_url or Anthropic image block)
        │
gateway intercepts the image part
        │
small VLM (Qwen3-VL-30B-A3B, separate workstation) describes it
under a strict transcription prompt
        │
the description TEXT replaces the image in the message
        │
GLM-5.2 (text-only) answers about the description
```

The interception lives at the gateway, so it works identically for
`/v1/chat/completions` and `/v1/messages`, for chat UIs and coding agents,
with nothing configured client-side. Multi-image messages and images
appearing mid-conversation are handled the same way.

## Why a bridge instead of a vision graft

We ran both. An in-model vision graft (MoonViT encoder grafted onto the
served checkpoint) worked — and lost the A/B on answer quality against the
bridge. Removing the graft also freed its ~1 GB of weights plus a
hand-carved activation reserve, which converted directly into context:
**316K → 380K tokens (+64K)**.

The deeper reason the bridge wins: a dedicated VLM's entire training budget
went into perception, and the big model's entire budget into reasoning.
Splitting the job puts each token of memory and each parameter where it
earns the most. The bridge VLM also runs on a separate workstation — image
traffic adds **zero load** to the inference cluster.

## The transcription prompt matters more than the model

The bridge's VLM prompt is engineered for factual fidelity, not flair. Its
load-bearing rules:

- Describe only what is visibly present; never infer a brand, place, name or
  value that is not actually written in the image.
- **Transcribe ALL visible text exactly, character by character**, preserving
  non-Latin scripts as the original characters — including small text:
  license plates, signs, labels, screenshots, code, error messages.
- If a text region is too small or blurred to read confidently, output
  `UNREADABLE` for that part instead of guessing.

That last rule is the difference between a vision bridge you can trust and
one that hallucinates plausible readings.

## Honest limits

- The reasoning model sees a *description*, not pixels. Tasks that need true
  spatial precision (measuring, pixel-perfect UI diffs) lose fidelity in the
  translation.
- VLM text transcription can normalize characters in stylized or decorative
  renderings (observed with Turkish diacritics in ornate typography). The
  bridge is excellent as a content reader and layout inspector; do not use
  it as a spelling proofreader for stylized text.
- Latency adds one VLM inference (seconds) before the main model's turn.

## One config knob

The whole feature is a gateway flag plus the VLM endpoint; the served model,
its context budget and its throughput are untouched. Turning it off returns
the system to a pure text API — nothing else changes.
