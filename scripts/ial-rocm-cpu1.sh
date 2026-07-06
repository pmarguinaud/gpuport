#!/bin/bash

set -x
set -e

tt=CPU_O1_ROCM2321_OPENMPI5.0.7

\rm -f build.$tt/bin/MASTERODB

../IAL/bundle/ial-bundle \
  build  \
  --build-dir build.$tt \
  -j 64 \
  --arch ../IAL/bundle/arch/fxtran/ \
  --verbose \
  --build-type FXTRAN_${tt} \
  --forecast-only

# --install-dir $PERM/IAL-$tt \

