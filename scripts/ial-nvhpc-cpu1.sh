#!/bin/bash

set -x
set -e

tt=CPU_O1_NVHPC26.5_CUDA12.9_HPCX2.25.1

\rm -f build.$tt/bin/MASTERODB

../IAL/bundle/ial-bundle \
  build  \
  --build-dir build.$tt \
  -j 32 \
  --arch ../IAL/bundle/arch/fxtran/ \
  --verbose \
  --build-type FXTRAN_${tt} \
  --forecast-only

# --install-dir $workdir/IAL-$tt \

