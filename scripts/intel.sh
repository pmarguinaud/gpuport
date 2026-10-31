#!/bin/bash

nthread=16

set -e
set -x

function installINTEL ()
{
  b=$(basename $URL)

  if [ -x "$INSTALL/intel/oneapi/compiler/$version/bin/ifx" ]
  then
    return
  fi

  if [ ! -f "$b" ]
  then
    wget $URL
  fi

  # Force temporary files to be extracted in $TMP
  \rm -rf intel
  HOME=$TMP \
  sh ./$b -a --cli --action install --components all --install-dir=$INSTALL/intel/oneapi --eula accept --silent
}

function installHDF5 ()
{
  t=$SOURCES/hdf5-1.14.6.tar.gz

  b=$(basename $t .tar.gz)

  if [ ! -f $t ]
  then
    wget -O $t https://support.hdfgroup.org/releases/hdf5/v1_14/v1_14_6/downloads/hdf5-1.14.6.tar.gz
  fi

  if [ -d "$INSTALL/intel/$version/hdf5/1.14.3" ]
  then
    return
  fi

  \rm -rf $b

  tar xf $t

  cd $b
  LDFLAGS="$intelrpath" \
  ./configure --prefix=$INSTALL/intel/$version/hdf5/1.14.3 --enable-fortran
  make -j$nthread
  make install
  cd ..
}

function installNETCDF ()
{
  hdf5prefix=$INSTALL/intel/$version/hdf5/1.14.3
  netcdf4prefix=$INSTALL/intel/$version/netcdf4/4.9.2

  if [ -d "$netcdf4prefix" ]
  then
    return
  fi

  t=$SOURCES/netcdf-c-4.9.3.tar.gz

  if [ ! -f $t ]
  then
    wget -O $t https://github.com/Unidata/netcdf-c/archive/refs/tags/v4.9.3.tar.gz
  fi

  b=$(basename $t .tar.gz)
  \rm -rf $b
  tar xf $t

  cd $b
  CFLAGS="-I$hdf5prefix/include -fPIC" \
  LDFLAGS="-L$hdf5prefix/lib -Wl,-rpath,$hdf5prefix/lib $intelrpath" \
  ./configure --prefix=$netcdf4prefix --disable-dap
  make -j$nthread
  make install
  cd ..

  t=$SOURCES/netcdf-fortran-4.6.2.tar.gz

  if [ ! -f $t ]
  then
    wget -O $t https://github.com/Unidata/netcdf-fortran/archive/refs/tags/v4.6.2.tar.gz
  fi

  b=$(basename $t .tar.gz)
  \rm -rf $b
  tar xf $t

  cd $b
  CPPFLAGS="-I$netcdf4prefix/include" \
  FCFLAGS="-fPIC" \
  LDFLAGS="-L$netcdf4prefix/lib -Wl,-rpath,$netcdf4prefix/lib -L$hdf5prefix/lib -Wl,-rpath,$hdf5prefix/lib $intelrpath" \
  ./configure --prefix=$netcdf4prefix
  make -j$nthread
  make install
  cd ..
}

function installMODULE ()
{
  mkdir -p $INSTALL/modulefiles/intel

  cat > $INSTALL/modulefiles/intel/$version << EOF
#%Module1.0

conflict intel
conflict rocm
conflict nvhpc
conflict nvhpc-nompi
conflict nvhpc-byo-compiler
conflict nvhpc-hpcx

set oneapi $INSTALL/intel/oneapi

source-sh bash \$oneapi/compiler/$version/env/vars.sh
source-sh bash \$oneapi/mpi/latest/env/vars.sh
source-sh bash \$oneapi/mkl/latest/env/vars.sh

setenv CC icx
setenv CXX icpx
setenv FC ifx
setenv F90 ifx
setenv F77 ifx
setenv CPP cpp
EOF
}

prefix=$(dirname $0)
prefix=$(dirname $prefix)
prefix=$(realpath $prefix)

INSTALL=$prefix/install
SOURCES=$prefix/sources
TMP=$prefix/tmp

mkdir -p $INSTALL $SOURCES

URL=$1

if [ "x$URL" = "x" ]
then
  URL="https://registrationcenter-download.intel.com/akdlm/IRC_NAS/5996e26b-f48a-42b1-8db0-b002ad0bd8d7/intel-oneapi-toolkit-2026.1.1.33_offline.sh"
fi

if [[ $URL =~ intel-oneapi-toolkit-([0-9]+\.[0-9]+)\.[0-9]+\.[0-9]+_offline\.sh$ ]]
then
  version="${BASH_REMATCH[1]}"
else
  exit 1
fi

mkdir -p $TMP
cd $TMP

installINTEL

# vars.sh does not like set -e / set -x
set +e +x
source $INSTALL/intel/oneapi/compiler/$version/env/vars.sh
set -e -x

export CC=icx
export CXX=icpx
export FC=ifx

# Intel runtime libraries (libimf, libsvml, libifcoremt, ...) are not found without this
intelrpath="-Wl,-rpath,$INSTALL/intel/oneapi/compiler/$version/lib"

installHDF5

installNETCDF

installMODULE

