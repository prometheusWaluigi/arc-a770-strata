#!/usr/bin/env bash
# Real-prompt smoke WITHOUT verify-debug: the actual decode path, cache=1 arm.
set -u
cd "${STRATA_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)}"
LOG="$1"; shift
EXTRAENV="${1:-}"; [ $# -gt 0 ] && shift
[ "${1:-}" = "--" ] && shift

M=Strata-data/models/coder-iq1m/IQ1_M
S1=$M/Qwen3.8-Flash-Next-GSQ-RCO-IQ1_M-00001-of-00002.gguf
S2=$M/Qwen3.8-Flash-Next-GSQ-RCO-IQ1_M-00002-of-00002.gguf

STRATA_RUN_ENV="STRATA_DXG_SHARED_FALLBACK=1 $EXTRAENV" \
timeout -k 10 240 ./run-strata.sh \
  --pack Strata-data/packs/coder-iq1m \
  --native "$S1" \
  --native-dense-gguf "$S1" --native-dense-gguf "$S2" \
  --ple-gguf "$S2" \
  --stream-token --native-head-gguf "$S1" \
  --mtp Strata-data/mtp/rt \
  --mmap-experts \
  --expert-profile data/expert-profile-coder.bin \
  --expert-cache "${STRATA_CACHE:-1}" --spec "${STRATA_SPEC:-4}" \
  --prefill auto --max-new "${STRATA_MAXNEW:-48}" \
  --tokens "${STRATA_TOKENS:-1,2,3,4,5,6,7,8,9,10,11,12,13}" \
  "$@" > "Strata-data/runs/$LOG" 2>&1
rc=$?
docker rm -f strata-run >/dev/null 2>&1
echo "run $LOG rc=$rc"
tail -12 "Strata-data/runs/$LOG"
