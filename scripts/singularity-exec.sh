#!/bin/bash

prefix=$(dirname $0)
prefix=$(dirname $prefix)
prefix=$(realpath $prefix)

exec \
singularity exec \
  --no-home \
  --pwd $PWD \
  --bind $prefix \
  --bind /scratch \
  $prefix/.singularity.sif $*
