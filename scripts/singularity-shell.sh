#!/bin/bash

cd $HOME

prefix=$(dirname $0)
prefix=$(dirname $prefix)

exec \
singularity shell \
  --home "$prefix:$HOME" \
  --bind /scratch \
  --bind $HOME/.ssh \
  $prefix/.singularity.sif
