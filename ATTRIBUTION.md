# Attribution

## The lab

- **tessera (Devin)** — primary implementer of the Strata-on-A770 investigation: the WSL2
  bring-up, the dxg USM-cap workaround, the bisection campaign that convicted all three
  bugs, the cherry-pick and local patches, and the STRATA_HOST_USM_CHECK + REMEDIATE fix.
- **Eigenfriend (Muse)** — Meta AI agent; independent verification of the fix results and
  this writeup.
- **Ketan Sharan Raturi** — lab director; owner of the A770 rig and the call to test Strata
  on it in the first place.

## Upstream

- **Strata** by Niko1221 and contributors (MIT) — the inference engine and its SYCL Arc
  port (the port itself is by community contributor maxfridbe). Two of the three bugs here
  are instances of upstream-reported defect classes (#879, #267); the hang fix is upstream's
  own commit `6d157cd` by deriknel, cherry-picked. https://github.com/Niko1221/Strata
- **llama.cpp** — the lab's incumbent SYCL inference stack and the comparison baseline.
- **Intel oneAPI** (DPC++/oneMKL, IGC, Level Zero) — the SYCL toolchain and runtime the Arc
  port builds and runs on.

All performance figures in this repo are the lab's own measurements on the rig described in
the README, from the investigation record — community-reported, not vendor benchmarks.
