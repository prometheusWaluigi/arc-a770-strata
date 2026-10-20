#!/usr/bin/env bash
# Lottery-rate harness: N identical cold boots of the cache=1/spec=4 arm.
# Each boot is an independent process/container = independent coin flip.
# Classifier: soup if >50% of output token ids after position 0 are 248046.
# usage: ./run-lottery.sh <N> <tag>
set -u
cd "${STRATA_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)}"
N="${1:-6}"; TAG="${2:-lot}"
[ $# -gt 0 ] && shift; [ $# -gt 0 ] && shift
export STRATA_MAXNEW="${STRATA_MAXNEW:-16}"
export STRATA_TOKENS="${STRATA_TOKENS:-1,2,3,4,5,6,7,8,9,10,11,12,13}"

good=0; soup=0; other=0
for i in $(seq 1 "$N"); do
  log="${TAG}${i}.log"
  extra=""
  if [ -n "${FLPREFIX:-}" ]; then
    extra="STRATA_DUMP_FIRST_LOGITS=Strata-data/runs/${FLPREFIX}${i}.bin"
  fi
  if [ -n "${PFPREFIX:-}" ]; then
    extra="$extra STRATA_PREFILL_DUMP_R_ALL=Strata-data/runs/${PFPREFIX}${i}.bin"
  fi
  if [ -n "${GSPREFIX:-}" ]; then
    extra="$extra STRATA_STATE_DUMP_GDN=Strata-data/runs/${GSPREFIX}${i}.bin"
  fi
  if [ -n "${VDPREFIX:-}" ]; then
    extra="$extra STRATA_VERIFY_DEBUG=1 STRATA_VERIFY_DBGDUMP=Strata-data/runs/${VDPREFIX}${i}.bin"
  fi
  if [ -n "${GTPREFIX:-}" ]; then
    extra="$extra STRATA_GDN_TAP=Strata-data/runs/${GTPREFIX}${i}.bin"
  fi
  if [ -n "${GRPREFIX:-}" ]; then
    extra="$extra STRATA_GRIN_TAP=Strata-data/runs/${GRPREFIX}${i}.bin"
  fi
  if [ -n "${RTPREFIX:-}" ]; then
    extra="$extra STRATA_ROUTE_TAP=Strata-data/runs/${RTPREFIX}${i}.bin"
  fi
  if [ -n "${PLPREFIX:-}" ]; then
    extra="$extra STRATA_PLAN_TAP=Strata-data/runs/${PLPREFIX}${i}.bin"
  fi
  if [ -n "${MOPREFIX:-}" ]; then
    extra="$extra STRATA_MOE_TAP=Strata-data/runs/${MOPREFIX}${i}.bin"
  fi
  if [ -n "${PLTPREFIX:-}" ]; then
    extra="$extra STRATA_PLE_TAP=Strata-data/runs/${PLTPREFIX}${i}.bin"
  fi
  if [ -n "${MPPREFIX:-}" ]; then
    extra="$extra STRATA_MPLE_TAP=Strata-data/runs/${MPPREFIX}${i}.bin"
  fi
  if [ -n "${EXTRAENV:-}" ]; then
    extra="$extra $EXTRAENV"
  fi
  ./run-real.sh "$log" "$extra" -- "$@" >/dev/null 2>&1
  f="Strata-data/runs/$log"
  line=$(grep '^output' "$f" | tail -1)
  if [ -z "$line" ]; then
    verdict=other; other=$((other+1))
  else
    toks=${line#output  :}
    total=0; imend=0
    for t in $toks; do
      total=$((total+1))
      [ "$t" = "248046" ] && imend=$((imend+1))
    done
    # position 0 is <think> (248068); judge the remainder
    rest=$((total-1)); imend_rest=$imend
    if [ "$rest" -gt 0 ] && [ $((imend_rest*2)) -gt "$rest" ]; then
      verdict=soup; soup=$((soup+1))
    else
      verdict=good; good=$((good+1))
    fi
  fi
  dec=$(grep -oP 'decode\s+\d+ tokens in [\d.]+ ms\s+->\s+[\d.]+ tok/s' "$f" | tail -1)
  echo "boot $i: $verdict  [$line]  $dec"
done
echo "LOTTERY $TAG: N=$N good=$good soup=$soup other=$other"
