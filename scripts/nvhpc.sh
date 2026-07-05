#!/bin/bash

nthread=16

set -e
set -x

function installNVHPC ()
{
  dir=$(basename $URL .tar.gz)

  if [ -d "$INSTALL/nvidia/hpc_sdk/Linux_x86_64/$version" ]
  then
    return
  fi

  if [ ! -f "$dir.tar.gz" ]
  then
    wget $URL
  fi

  tar xf "$dir.tar.gz"

  cd $dir

  cat -> install.in << EOF

1
$INSTALL/nvidia/hpc_sdk
EOF

  ./install < install.in

  cd ..

  \rm -rf $dir
}

function installHDF5 ()
{
  t=$SOURCES/hdf5-1.14.6.tar.gz

  b=$(basename $t .tar.gz)

  if [ ! -f $t ]
  then
    wget -O $t https://support.hdfgroup.org/releases/hdf5/v1_14/v1_14_6/downloads/hdf5-1.14.6.tar.gz
  fi

  if [ -d "INSTALL/nvhpc/$version/hdf5/1.14.3" ]
  then
    return
  fi

  \rm -rf $b

  tar xf $t

  cd $b
  ./configure --prefix=$INSTALL/nvhpc/$version/hdf5/1.14.3 --enable-fortran 
  make -j$nthread
  make install 
  cd ..
}

function installNETCDF ()
{
  hdf5prefix=$INSTALL/nvhpc/$version/hdf5/1.14.3
  netcdf4prefix=$INSTALL/nvhpc/$version/netcdf4/4.9.2

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
  netcdf_c=$b
  \rm -rf $b
  tar xf $t

  cd $b
  CFLAGS="-I$hdf5prefix/include -fPIC" \
  LDFLAGS="-L$hdf5prefix/lib -Wl,-rpath,$hdf5prefix/lib" \
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
  LDFLAGS="-L$netcdf4prefix/lib -Wl,-rpath,$netcdf4prefix/lib -L$hdf5prefix/lib -Wl,-rpath,$hdf5prefix/lib" \
  ./configure --prefix=$netcdf4prefix
  make -j$nthread
  make install 
  cd ..
}

prefix=$(dirname $0)
prefix=$(dirname $prefix)
prefix=$(realpath $prefix)

INSTALL=$prefix/install
SOURCES=$prefix/sources
TMP=$prefix/tmp

mkdir -p $INSTALL $SOURCES

URL=$1 

if [ "x$URL"  = "x" ]
then
  URL="https://developer.download.nvidia.com/hpc-sdk/26.5/nvhpc_2026_265_Linux_x86_64_cuda_multi.tar.gz"
fi

if [[ $URL =~ /hpc-sdk/([0-9]+\.[0-9]+)/ ]]
then
  version="${BASH_REMATCH[1]}"
else
  exit 1
fi

mkdir -p $TMP
cd $TMP

installNVHPC

export MODULEPATH=$INSTALL/nvidia/hpc_sdk/modulefiles:$MODULEPATH
module load nvhpc/$version

installHDF5

installNETCDF



