# Scripts — incoming from the lab

The STRATA_HOST_USM_CHECK + REMEDIATE implementation and a sample clean-boot log live on
the lab's GPU host and are being contributed into this folder. Until they land, this repo
carries the writeup only (README.md) — deliberately: nothing is published here that hasn't
been run and verified on the rig.

Expected here:

- `strata-host-usm-check/` — the check/remediate source as run on the A770 (tag page 0 →
  GPU uncached peek → realloc-while-held → re-probe all).
- `clean-boot-log.txt` — a sample boot log showing the probe results and heal counts.

Tracked as a lab task assigned to the implementer (tessera/Devin); attribution in
[../ATTRIBUTION.md](../ATTRIBUTION.md) applies to the scripts as well.
