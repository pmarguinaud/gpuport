#!/bin/bash

set -x
set -e

URL=$1

if [ "x$URL" = "x" ]
then
  URL="https://registrationcenter-download.intel.com/akdlm/IRC_NAS/db60f483-f02e-4f7e-9bcd-5e01dba97444/intel-onemkl-2026.0.0.909_offline.sh"
fi

install=$HOME/install

mkdir -p $install $HOME/tmp

cd $HOME/tmp

b=$(basename $URL)

if [ ! -f "$b" ]
then
  wget $URL
fi

if [[ $URL =~ intel-onemkl-([0-9]+\.[0-9]+)\.[0-9]+\.[0-9]+_offline\.sh$ ]] 
then
  version="${BASH_REMATCH[1]}"
else
  exit 1
fi

if [ ! -d "$install/intel/oneapi/mkl/$version" ]
then
  sh ./$b  -a --cli --action install --components all --install-dir $HOME/install/intel/oneapi  --eula accept --silent
fi

\rm -rf $HOME/intel
