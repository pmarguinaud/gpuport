#!/bin/bash

prefix=$(dirname $0)
prefix=$(dirname $prefix)

exec \
singularity exec \
  --home "$prefix:$HOME" \
  --bind /scratch \
  $prefix/.singularity.sif $*
