#!/bin/bash

nthread=16

set -e
set -x

function installROCM ()
{
  dir=$(basename $URL .tar.bz2)

  if [ -d "$INSTALL/rocm/$dir" ]
  then
    return
  fi

  if [ ! -f "$dir.tar.bz2" ]
  then
    wget $URL
  fi

  mkdir -p $INSTALL/rocm

  tar xf $dir.tar.bz2 -C $INSTALL/rocm

  ln -s $dir $INSTALL/rocm/$VV
}

function installOPENMPI ()
{
  t=$SOURCES/openmpi-5.0.7.tar.gz

  if [ ! -f $t ] 
  then
    wget -O $t https://download.open-mpi.org/release/open-mpi/v5.0/openmpi-5.0.7.tar.gz
  fi

  b=$(basename $t .tar.gz)

  if [ -d "$INSTALL/rocm/$VV/openmpi-5.0.7" ]
  then
    return
  fi

  \rm -rf $b 

  tar xf $t

  cd $b

  ./configure --prefix=$INSTALL/rocm/$VV/openmpi-5.0.7 --with-pmix

  make -j$nthread
  make install 

  cd ..
}

function installHDF5 ()
{
  t=$SOURCES/hdf5-1.14.6.tar.gz

  if [ ! -f $t ]
  then
    wget -O $t https://support.hdfgroup.org/releases/hdf5/v1_14/v1_14_6/downloads/hdf5-1.14.6.tar.gz
  fi

  b=$(basename $t .tar.gz)

  if [ -d "$INSTALL/rocm/$VV/hdf5/1.14.3" ]
  then
    return
  fi

  \rm -rf $b "$b-build"

  tar xf $t

  FFLAGS="-Wl,--allow-shlib-undefined" \
  cmake -S $b -B "$b-build" -DCMAKE_INSTALL_PREFIX=$INSTALL/rocm/$VV/hdf5/1.14.3 -DHDF5_ENABLE_Z_LIB_SUPPORT=ON -DHDF5_BUILD_FORTRAN=ON \
  && cmake --build "$b-build" -j$nthread && cmake --install "$b-build"
}

function installNETCDF ()
{
  hdf5prefix=$INSTALL/rocm/$VV/hdf5/1.14.3
  netcdf4prefix=$INSTALL/rocm/$VV/netcdf4/4.9.2

  if [ -d $netcdf4prefix ]
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

if [ "x$URL" = "x" ]
then
  URL="https://repo.radeon.com/rocm/misc/flang/therock-afar-23.2.1-gfx94X-7.13.0-7357b5084b.tar.bz2"
fi

if [[ $URL =~ therock-afar-([0-9]+\.[0-9]+\.[0-9]+)- ]]
then
  version=${BASH_REMATCH[1]}
else
  exit 1
fi

VV=$(echo $version | sed -e 's/\.//g')

mkdir -p $TMP
cd $TMP

installROCM

export PATH=$INSTALL/rocm/$VV/bin:$PATH

export FC=amdflang
export CC=amdclang
export CXX=amdclang++

installOPENMPI

installHDF5

installNETCDF

