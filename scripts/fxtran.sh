#!/bin/bash

eval $(perl -I $HOME/perl5/lib/perl5 -Mlocal::lib)

cd $HOME/install

git clone https://github.com/pmarguinaud/fxtran
cd fxtran

make 
cd perl5
make install
