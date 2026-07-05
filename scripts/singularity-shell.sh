#!/bin/bash

prefix=$(dirname $0)
prefix=$(dirname $prefix)
prefix=$(realpath $prefix)

cd $prefix

mkdir -p $prefix/.vim
mkdir -p $prefix/.cpanm

exec \
singularity shell \
  --no-home \
  --pwd $prefix \
  --bind $prefix \
  --bind $prefix/.vim:$HOME/.vim \
  --bind $prefix/.cpanm:$HOME/.cpanm \
  --bind /scratch \
  --bind $SSL_CERT_FILE \
  --bind $SSL_CERT_DIR \
  --bind $HOME/.vimrc:$HOME/.vimrc:ro \
  --bind $HOME/.ssh:$HOME/.ssh:ro \
  --bind $HOME/.gitconfig:$HOME/.gitconfig:ro \
  --bind $HOME/.git-credentials:$HOME/.git-credentials:ro \
  $prefix/.singularity.sif
