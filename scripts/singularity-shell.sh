#!/bin/bash

cd $HOME

prefix=$(dirname $0)
prefix=$(dirname $prefix)

exec \
singularity shell \
  --home "$prefix:$HOME" \
  --bind /scratch \
  --bind $HOME/.ssh \
  --bind $SSL_CERT_FILE \
  --bind $SSL_CERT_DIR \
  --bind $HOME/.git-credentials \
  $prefix/.singularity.sif
