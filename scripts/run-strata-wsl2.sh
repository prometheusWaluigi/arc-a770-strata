#!/usr/bin/env bash
# Run the SYCL strata engine inside strata-sycl-dev with the A770 visible (WSL2 recipe).
# Usage: STRATA_RUN_ENV="A=1 B=2" ./run-strata.sh [strata args...]
envs=(-e LD_LIBRARY_PATH=/usr/lib/wsl/lib:/opt/intel/oneapi/2026.1/lib:/opt/intel/oneapi/compiler/2026.1/lib:/opt/intel/oneapi/mkl/2026.1/lib
      -e SYCL_CACHE_PERSISTENT=0 -e ZES_ENABLE_SYSMAN=1
      -e STRATA_VERIFY_DEVICE_PLAN=1 -e ONEAPI_DEVICE_SELECTOR=level_zero:0 -e IGC_EnableDPEmulation=1 -e OverrideDefaultFP64Settings=1 -e NEOReadDebugKeys=1)
for kv in ${STRATA_RUN_ENV:-}; do envs+=(-e "$kv"); done
exec docker run --rm -i --name strata-run \
  --device /dev/dri --device /dev/dxg \
  --ulimit memlock=-1 --oom-score-adj 1000 --stop-timeout 30 \
  -v /usr/lib/wsl:/usr/lib/wsl \
  -v "${STRATA_PARENT:?set STRATA_PARENT to the directory containing the strata checkout}:/work" \
  "${envs[@]}" \
  strata-sycl-dev \
  "cd "/work/${STRATA_DIRNAME:-strata}" && exec build-sycl/strata $*"
