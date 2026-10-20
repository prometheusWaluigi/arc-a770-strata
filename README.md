# arc-a770-strata

Running real models on an **Intel Arc A770** — specifically the
[Strata](https://github.com/Niko1221/Strata) inference engine (built for the Qwen3.8-Flash-Next
MoE) through its experimental SYCL Arc port, on hardware upstream lists as *untested*.

The A770 is the Sharan homelab's one GPU. This repo is the lab's field record of getting a
large MoE to load, decode, and — hardest of all — decode *the same way twice* on Alchemist:
three distinct bugs root-caused, two of them matching known upstream defect classes, and a
check/remediate pattern for the third that generalizes to any host-USM staging buffer.

## The rig

- Intel Arc A770, 16 GB (Alchemist, device 0x56a0)
- Windows host + WSL2; Strata runs in the `strata-sycl-dev` Docker image (~13 GB) with
  oneAPI DPC++ 2026.1 + oneMKL
- Engine 0.1.44.1, JIT-compiled (Alchemist has no AOT target; AOT is Battlemage-only)
- Model: Qwen3.8-Flash-Next, IQ quants; experts partly resident on card, rest mirrored in RAM

## Bring-up notes (the undocumented parts)

- **WSL2 GPU visibility:** the container needs `--device /dev/dri` + `/dev/dxg`, a mount of
  `/usr/lib/wsl`, and `LD_LIBRARY_PATH` covering `/usr/lib/wsl/lib` and the oneAPI lib dirs.
  Upstream's `setup_intel.py` assumes `/sys/class/drm` and is unusable here; every step was
  run by hand.
- **fp64 keys are load-bearing:** Alchemist has no hardware fp64. Without
  `IGC_EnableDPEmulation=1`, `OverrideDefaultFP64Settings=1`, `NEOReadDebugKeys=1`, test
  oracles abort with `'double' is not supported` — and an early decode hang traced back to
  exactly this class of kernel-launch throw.
- **dxg caps a single USM allocation at exactly 1024 MiB** (probed: 1024 MiB OK, 1040 MiB
  NULL; device and host USM alike; many smaller blocks fine; `malloc_shared` exempt).
  Strata's few-big-arenas allocation style hits this immediately. Workaround: an opt-in
  `STRATA_DXG_SHARED_FALLBACK=1` patch (5 lines) falling back to `malloc_shared` in the
  guarded device allocator. llama.cpp survives on this rig because it allocates per-tensor.

## Bug 1 — the expert-cache-hit NaN (upstream #879 class)

Decode produced all-nonfinite residuals at a fixed layer: every pinned-oracle arm (QSA,
GDN, MoE combine, BF16 projections, router, rope) matched the reference to 4 significant
figures until the flip, which exonerated each in turn. Convicted by subtraction: the GPU
**resident-expert cache-hit path**. A de-cached run (`--expert-cache 1`) produced **zero
nonfinite values across all 55 layers** and finite decode — matching upstream issue #879's
instrumented verdict (cache-hit expert rows emitting non-canonical NaN `0x7FFFFFFF`; reported
on CUDA and ROCm, runtime-library dependent). Our repro is *deterministic* — same prompt,
same layer, every run — where upstream's was Monte-Carlo.

**Workaround that works today: `--expert-cache 1`.**

## Bug 2 — the decode hang (upstream #267): Verifier::done()

The second bug wedged the engine mid-decode: main thread userspace-spinning, all workers
parked — a completion flag that never became host-visible. Upstream shipped the fix while
the lab was bisecting: commit `6d157cd` (issue #267 follow-up). Root cause:
`Verifier::done()` kept a CUDA-era dpct placeholder for its completion check —
`sycl_event_query` returns 1 for a command *still running*, so the first pipelined window
that hadn't finished when polled failed the whole request, and teardown wedged the engine.

Cherry-picked onto the 0.1.44.1 tree and rebuilt, the real arm ran clean: **64/64 tokens at
3.93 tok/s, zero errors — the first full decode on the A770** through the pipelined path
(a correctness milestone, not a performance claim). A second site with the same placeholder
shape, `pl_commit_async`'s unbounded poll, was found locally and patched with the same
bounded-poll pattern (2 ms queue flush, 20 s timeout, release GPU waits).

## Bug 3 — the per-boot coin flip, and the host-USM check/remediate pattern

After the hang fix, output quality flipped per boot, roughly 50/50: good boots produced real
reasoning text; bad boots collapsed into special-token soup from position 1 — with
position-0 logits healthy even on bad boots. Beats of bisection unified both "coins" (a
doorbell payload invisible where the graph reads; garbage injected into a buffer's first
page) into **one mechanism**:

> **A boot-time PTE alias on host-USM staging pages.** The GPU's uncached view of one
> buffer's page 0 was bit-identical to another buffer's page 0 — live (changes tracked
> copy-time → window-end), whole-boot persistent, pages 1–7 correct. It is not a write
> that misses; it is a read that lands on the wrong physical page.

The fix, **STRATA_HOST_USM_CHECK + REMEDIATE**, is a pattern worth keeping beyond Strata:

1. Tag page 0 of each staging buffer with a per-buffer pattern.
2. Peek through the GPU (uncached) and compare.
3. On mismatch, realloc *while the old buffer is still held* — so the fresh VA/page cannot
   be the stale one — then free the old buffer.
4. Re-probe all buffers.

Results: **24/24 boots bit-exact clean** (8/8 + 16/16 across two harnesses), zero soup, zero
refusals, heal counts up to 6 — and **12 of 16 boots in one harness woke up with at least
one alias already present**. At ~75% incidence this is a routine host-USM / Level-Zero-dxg
aliasing condition on this rig, not a rare coin: the check belongs at init for *any* mapped
staging buffer, not just Strata's.

## Model-running notes

- **llama.cpp SYCL** is the lab's incumbent stack on this card (per-tensor allocation is why
  it never met the dxg cap); Strata is the candidate for the big-MoE seat because of expert
  streaming and its own kernels.
- **One card, many tenants:** the lab serializes GPU work through a simple queue (the lab
  calls it *gpuq*) — a single A770 shared by text, image, and experiment workloads runs one
  job at a time, with supervised runs for anything in bring-up. Several bugs above only
  reproduce under real queue conditions, so the discipline is part of the results.
- On a 16 GB card, a Flash-Next-class MoE is a RAM story as much as a VRAM story: mirrored
  experts make system memory part of the performance picture.

## Status & what's not here (yet)

- The investigation record lives in the lab; an upstream report in community-benchmark
  format has been drafted in-lab. This repo is the public writeup.
- **Scripts have landed**: the `STRATA_HOST_USM_CHECK` + REMEDIATE implementation, the
  boot-lottery harness, and a sample clean-boot log live under [`scripts/`](scripts/)
  (index: `docs/SCRIPTS-INCOMING.md`). Nothing in this repo is a script we haven't run.

## License & attribution

MIT — see [LICENSE](LICENSE). Who did what: [ATTRIBUTION.md](ATTRIBUTION.md).
