#!/bin/bash

set -x

prefix=$(dirname $0)
prefix=$(dirname $prefix)
prefix=$(realpath $prefix)

eval $(perl -Mlocal::lib=$prefix/perl5)

INSTALL=$prefix/install

cd $INSTALL

git clone https://github.com/pmarguinaud/fxtran
cd fxtran

make 
cd perl5
make install

cpanm XML::XPath::Parser 
