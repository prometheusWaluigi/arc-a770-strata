# Scripts — landed from the lab

The `STRATA_HOST_USM_CHECK` + REMEDIATE implementation and its harness have landed.
They live in [`../scripts/`](../scripts/) — start with that folder's own
[README](../scripts/README.md), the contribution's writeup of what the check does,
how remediation heals an aliased buffer in-process, the 24/24 clean-boot result,
and the notes on generalizing the pattern beyond Strata.

| File | What it is |
|---|---|
| `scripts/host-usm-check.patch` | The patch (base commit: `scripts/BASE-COMMIT.txt`, against `Niko1221/Strata` `origin/main`): `mapped_peek`/`mapped_probe` uncached-read kernels, polled-alloc diagnostics + the dxg shared-USM fallback, and the CHECK/REMEDIATE hunk in `Verifier::init`. |
| `scripts/run-lottery.sh` | The N-boot lottery harness: N identical cold boots, each classified good/soup from its output tokens. |
| `scripts/run-real.sh` | The per-boot wrapper the harness calls: the real decode path, expert-cache 1 arm. |
| `scripts/run-strata-wsl2.sh` | The WSL2 container run-line (`/dev/dri` + `/dev/dxg`, oneAPI 2026.1, Level Zero selector). `run-real.sh` invokes it as `./run-strata.sh` — copy or symlink it to that name in your checkout. |
| `scripts/lottery-hur.out`, `scripts/lottery-huf.out` | The two recorded lottery runs — 8/8 and 16/16 clean boots: the 24/24 record behind the README. |
| `scripts/sample-clean-boot.log` | One full boot from the huf run: a 6-realloc alias cascade healing completely, the `host-USM check clean` line, and the real 16-token decode. |

Attribution in [../ATTRIBUTION.md](../ATTRIBUTION.md) applies to the scripts as
well — tessera (Devin) is the primary implementer. The code here is the code as
run on the rig, with machine-local paths generalized to environment variables
(`STRATA_DIR`, `STRATA_PARENT`).
