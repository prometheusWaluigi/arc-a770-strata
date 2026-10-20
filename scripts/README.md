# STRATA_HOST_USM_CHECK + REMEDIATE — contribution drop

Companion artifacts for the arc-a770-strata writeup. This is the code as it
ran on the Intel Arc A770 under WSL2 (Level Zero via `/dev/dxg`), cleaned for
public eyes. Base: `Niko1221/Strata` `origin/main` (see `BASE-COMMIT.txt`);
the patch applies with `git apply` (one hunk lands at offset −11 lines).

## What this is

On this rig, a boot can come up with a GPU page-table entry resolving a
mapped host-USM staging buffer's page 0 to the *wrong physical host page*.
The kernel then reads whatever another staging buffer (or an unmapped page)
lives there — a silent, boot-persistent fault that surfaces as a decode
"basin" (bit-identical wrong output for the whole process lifetime).

`STRATA_HOST_USM_CHECK=1` turns the fault loud at `Verifier::init`:

1. After all 16 mapped staging buffers exist, page 0 of each host buffer is
   tagged `0x5a5a<i>00 | j` (buffer index i, word j, 16 words).
2. Every buffer's device view is read back through a GPU *uncached* load
   (`mapped_peek`, same L1+L3-bypass path the real copy kernel uses).
3. Any mismatch names the offender — and the tag still legible in the
   foreign page names the *source* of the alias.

`STRATA_HOST_USM_REMEDIATE=N` (default 8, `1` = refuse on first sight) then
heals in-process: the aliased buffer is reallocated *while the old one is
still held* (the new VA cannot reuse the stale page), the old mapping is
freed, member pointers are updated through `void**` slots, the plan `sink_`
view is re-derived if `h_plan_` moved, and the whole set is re-probed.
Cascades happen (the freed stale page migrates to the next tenant) — the
sample log shows a 6-realloc cascade healing completely.

Related arms in the same patch: `host_malloc_polled` now says out loud when
uncached host USM was refused and plain `malloc_host` served the buffer (an
uncached-only kernel may then never see host stores), and
`STRATA_DXG_SHARED_FALLBACK=1` lets `malloc_device_guarded` retry a refused
>1 GiB device alloc as shared USM (the dxg single-alloc cap).

## Results

- `lottery-hur.out` — N=8 cold boots, check+remediate armed: **8/8 clean
  boots**, bit-exact correct decode. Heals per boot: 2,2,0,2,5,2,2,3 — 7/8
  boots woke with ≥1 stale host-USM PTE alias and healed.
- `lottery-huf.out` — N=16 follow-up: **16/16 clean**, heals
  3,0,2,2,3,6,2,0,3,3,6,2,0,3,0,2. Combined 24/24 clean boots; the silent
  basin coin has not recurred.
- `sample-clean-boot.log` — one full huf6 boot: the alias cascade, the
  reallocs, `host-USM check clean (16 mapped staging buffers)`, the window
  captures, and the real 16-token decode.

## Files

- `host-usm-check.patch` — `elementwise.hpp` + `elementwise.dp.cpp`
  (`mapped_peek`/`mapped_probe` kernels), `sycl_queue.hpp` (polled-alloc
  diagnostics + dxg shared fallback), `verify.cpp` (the single CHECK/REMEDIATE
  hunk only — the tree's other `STRATA_*_TAP` debug arms are deliberately
  excluded).
- `run-lottery.sh` / `run-real.sh` — the N-boot lottery harness and its
  per-boot wrapper (paths generalized: set `STRATA_DIR`, or run from the
  checkout root).
- `run-strata-wsl2.sh` — the container run-line (WSL2 recipe: `/dev/dri` +
  `/dev/dxg`, oneAPI 2026.1 libs, Level Zero selector). Set `STRATA_PARENT`.

## Known generalizations before upstreaming

- The `probes[]` table is `Verifier`-specific by construction — names and
  (host, device-view) slot pairs must be adapted wherever this pattern is
  reused. It keys off members allocated by the existing `mapped()` helper,
  which is upstream code.
- `mapped_peek` needs an uncached mapped-load primitive
  (`strata::sys_load_mapped` here); on other stacks substitute the
  cache-bypassing load of the day — the check is meaningless through a
  cached read.
- The remedy relies on realloc-while-held so the fresh VA cannot alias the
  stale physical page; a free-then-alloc order can re-hand you the same
  page.
- Tags live in page 0 only; buffers smaller than 64 bytes tag what fits.
