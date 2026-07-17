#!/bin/bash

cat -> apt.sh << EOF
#!/bin/bash 

set -eux

export DEBIAN_FRONTEND=noninteractive 
export TZ=Europe/Paris

rm -f /etc/apt/sources.list 
ln -fs /usr/share/zoneinfo/Europe/Paris /etc/localtime 
echo "Europe/Paris" > /etc/timezone 

# Update certificates first so that we can access snapshot.ubuntu.com

apt update -y 
apt install -y ca-certificates 
update-ca-certificates 

# Set snapshot

rm -rf /etc/apt/sources.list /etc/apt/sources.list.d/ubuntu.sources /var/lib/apt/lists/* 

cat -> /etc/apt/sources.list << DEB
deb http://snapshot.ubuntu.com/ubuntu/20260610T000000Z/ resolute main restricted universe multiverse
deb http://snapshot.ubuntu.com/ubuntu/20260610T000000Z/ resolute-updates main restricted universe multiverse
deb http://snapshot.ubuntu.com/ubuntu/20260610T000000Z/ resolute-security main restricted universe multiverse
DEB

# Reload package list

apt update -y
apt full-upgrade -y 
apt install -y unminimize 
yes | unminimize 

apt install -y command-not-found liblocal-lib-perl cmake make gcc gfortran git tzdata wget libwww-perl locales vim-nox \\
               man man-db manpages manpages-dev libxml-libxml-perl g++ perl-doc build-essential libgcc-13-dev libucx-dev ucx-utils \\
               libperl-dev libjson-perl libyaml-perl libdbi-perl cpanminus sqlite3 libsqlite3-dev environment-modules libterm-readline-perl-perl \\
               fypp libdbd-sqlite3-perl libopenmpi-dev openmpi-bin apt-file pciutils gdb psmisc htop libxml2-dev libpmix-dev \\
               libcurl4-openssl-dev xterm screen libxml2-utils tree time gawk bison flex gh curl ca-certificates rsync libaec-dev \\
               python3 python3-pip python3-venv strace valgrind ltrace linux-perf jq proxychains4 python3-setuptools libfile-type-perl 

sed -i 's/^# *fr_FR.UTF-8 UTF-8/fr_FR.UTF-8 UTF-8/' /etc/locale.gen 
locale-gen 
mandb 

apt-file update 

echo 'source /usr/share/modules/init/bash' >> /etc/bash.bashrc 

rm -rf /home/ubuntu 

apt-get clean 
rm -rf /var/lib/apt/lists/*
EOF

chmod +x apt.sh

cat -> singularity.def << EOF
Bootstrap: docker

From: ubuntu:resolute-20260610

%files
  /usr/local/share/ca-certificates/meteo-fr.crt /usr/local/share/ca-certificates/meteo-fr.crt
  /usr/local/share/ca-certificates/proxy1.crt   /usr/local/share/ca-certificates/proxy1.crt
  singularity.def                               /singularity.def
  apt.sh                                        /apt.sh

%post
  /apt.sh

%environment
  export GIT_SSL_NO_VERIFY=true
  export LANG=fr_FR.UTF-8
  export LANGUAGE=fr_FR:fr
  export LC_ALL=fr_FR.UTF-8

EOF

export TMPDIR=$HOME/tmp
export SINGULARITY_TMPDIR=$HOME/tmp

singularity build --fakeroot singularity.sif singularity.def


exit 0
singularity build --fakeroot --sandbox singularity   singularity.def  # image dans un repertoire
singularity shell --fakeroot --writable singularity                   # root
singularity shell singularity                                         # marguina
singularity build --fakeroot singularity.sif singularity              # creer un .sif a partir du repertoire

