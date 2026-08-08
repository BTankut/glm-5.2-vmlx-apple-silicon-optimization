# GB10 (DGX Spark) Operational Notes

Hard-won platform facts. GB10 is `sm_121a`, aarch64, unified LPDDR5X — a
lovely serving target with a few sharp edges.

## 1. Every engine shutdown leaks ~110 GiB per node

On this platform, **every** vLLM shutdown — including a perfectly graceful
`docker stop` — leaves ~110 GiB of unified memory unreclaimed per node. The
memory is held below the process level, so no amount of process cleanup
returns it.

- A **kernel module cycle** (unload/reload the NVIDIA modules) reclaims it —
  when the modules agree to unload.
- If a module refuses to unload, the only cure is a **reboot** of that node.

Practical consequence: **treat every model swap as a reboot cycle**, and run
a preflight gate before any boot (see [serving.md](serving.md)). Budgeting a
reboot into the swap procedure is cheaper than debugging a mysterious OOM at
90% of model load.

## 2. Never SIGKILL a CUDA container

`docker rm -f` / SIGKILL on a CUDA container makes the leak class above
strictly worse (memory that even a module cycle may not recover). Always
`docker stop -t <generous>` and let the engine exit cleanly.

## 3. Graceful-stop discipline applies to every node

TP=4 means four containers; stopping only the head leaves workers holding
memory. Stop on **every** node, then preflight.

## 4. CUDA-graph behaviour is config-coupled

The fitted capture-size rule in [serving.md](serving.md) is not cosmetic on
this platform: the single-request decode path is the common case, and stock
ladder padding cost a measured 8.4%. If you change `max-num-seqs` or the MTP
draft length, re-derive the capture list — the waste returns silently.

## 5. Full-SoC freezes exist independent of your serving stack

We observed hard node freezes (no panic, no vmcore, empty pstore, direct
reset) under several *different* heavy workloads on this hardware class —
including non-LLM ones. `kdump` was armed and proven with a deliberate crash,
yet real incidents captured nothing: the failure does not pass through the
kernel-panic path. The platform also reports
`watchdog: NMI not fully supported → Hard watchdog permanently disabled`.
Plan for it operationally (idempotent launchers, preflight, quick re-boot
runbooks) rather than assuming software forensics will explain it.
