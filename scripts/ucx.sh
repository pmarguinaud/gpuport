#!/bin/bash

nthread=16

set -e
set -x

function installUCX ()
{
  t=$SOURCES/ucx-$UCXVERSION.tar.gz

  if [ ! -f $t ]
  then
    wget -O $t https://github.com/openucx/ucx/releases/download/v$UCXVERSION/ucx-$UCXVERSION.tar.gz
  fi

  b=$(basename $t .tar.gz)

  if [ -d "$INSTALL/rocm/$VV/ucx" ]
  then
    return
  fi

  \rm -rf $b

  tar xf $t

  cd $b

  # --enable-mt is mandatory : MASTERODB requests MPI_THREAD_MULTIPLE, and the
  # UCX pml declines to be selected when the UCP worker does not support it
  # ("UCP worker does not support MPI_THREAD_MULTIPLE. PML UCX could not be selected").
  #
  # CFLAGS/CXXFLAGS and --disable-openmp are needed to build UCX 1.17.0 with gcc >= 14 :
  #   * UCX hardcodes -Werror in its BASE_CFLAGS
  #   * async.c uses pre-C23 function pointer idioms, rejected by default in C23
  #   * the perftest includes <omp.h> inside an extern "C" block, and the gcc 15
  #     header contains templates ("template with C linkage")

  ./configure --prefix=$INSTALL/rocm/$VV/ucx \
    --enable-mt --enable-optimizations \
    --with-verbs --with-mlx5-dv --with-rc --with-dc --with-ud --enable-cma \
    --without-cuda --without-rocm --without-knem --without-xpmem \
    --without-java --without-go --disable-openmp \
    --disable-logging --disable-debug --disable-assertions \
    CFLAGS="-Wno-error -std=gnu17" CXXFLAGS="-Wno-error"

  make -j$nthread
  make install

  cd ..

  $INSTALL/rocm/$VV/ucx/bin/ucx_info -v
}

prefix=$(dirname $0)
prefix=$(dirname $prefix)
prefix=$(realpath $prefix)

INSTALL=$prefix/install
SOURCES=$prefix/sources
TMP=$prefix/tmp

mkdir -p $INSTALL $SOURCES

UCXVERSION=1.17.0

VV=$1

if [ "x$VV" = "x" ]
then
  VV=2430
fi

mkdir -p $TMP
cd $TMP

installUCX
