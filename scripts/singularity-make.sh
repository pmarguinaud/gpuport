#!/bin/bash

# Build a reproducible Ubuntu 26.04 (resolute) container: every package comes
# from snapshot.ubuntu.com at a fixed date, and the base image is pinned by digest.
#
# Inside the Météo-France network, export the proxy before running this script;
# singularity passes http_proxy/https_proxy to the %post section:
#   export http_proxy=http://proxy.meteo.fr:11011
#   export https_proxy=http://proxy.meteo.fr:11011

set -eu

cd "$(dirname "$0")"

SNAPSHOT=20260610T000000Z

# ubuntu:resolute-20260610 (multi-arch index digest); tags can be re-pushed, digests cannot
IMAGE=ubuntu@sha256:53958ec7b67c2c9355df922dd08dbf0360611f8c3cdb656875e81873db9ffdba

cat -> apt.sh << EOF
#!/bin/bash

set -eux

export DEBIAN_FRONTEND=noninteractive
export TZ=Europe/Paris

ln -fs /usr/share/zoneinfo/Europe/Paris /etc/localtime
echo "Europe/Paris" > /etc/timezone

# Use the snapshot only: never touch the live archive, otherwise newer packages
# (e.g. libssl3t64) get installed and conflict with the snapshot

rm -rf /etc/apt/sources.list /etc/apt/sources.list.d/* /var/lib/apt/lists/*

cat -> /etc/apt/sources.list << DEB
deb https://snapshot.ubuntu.com/ubuntu/$SNAPSHOT/ resolute main restricted universe multiverse
deb https://snapshot.ubuntu.com/ubuntu/$SNAPSHOT/ resolute-updates main restricted universe multiverse
deb https://snapshot.ubuntu.com/ubuntu/$SNAPSHOT/ resolute-security main restricted universe multiverse
DEB

echo 'Acquire::Retries "5";' > /etc/apt/apt.conf.d/80retries

# snapshot.ubuntu.com redirects http to https, and the base image has no CA certificates;
# bootstrap ca-certificates without TLS verification (packages are still checked
# against the GPG-signed Release files), then add the Météo-France certificates

apt-get -o Acquire::https::Verify-Peer=false update
apt-get -o Acquire::https::Verify-Peer=false install -y ca-certificates
update-ca-certificates

# From now on, TLS is verified

apt-get update
apt-get full-upgrade -y
apt-get install -y unminimize
yes | unminimize

apt-get install -y command-not-found liblocal-lib-perl cmake make gcc gfortran git tzdata wget libwww-perl locales vim-nox \\
               man man-db manpages manpages-dev libxml-libxml-perl g++ perl-doc build-essential libgcc-13-dev libucx-dev ucx-utils \\
               libperl-dev libjson-perl libyaml-perl libdbi-perl cpanminus sqlite3 libsqlite3-dev environment-modules libterm-readline-perl-perl \\
               fypp libdbd-sqlite3-perl libopenmpi-dev openmpi-bin apt-file pciutils gdb psmisc htop libxml2-dev libpmix-dev xsel xclip \\
               libcurl4-openssl-dev xterm screen libxml2-utils tree time gawk bison flex gh curl ca-certificates rsync libaec-dev \\
               python3 python3-pip python3-venv strace valgrind ltrace linux-perf jq proxychains4 python3-setuptools libfile-type-perl

sed -i 's/^# *fr_FR.UTF-8 UTF-8/fr_FR.UTF-8 UTF-8/' /etc/locale.gen
locale-gen
mandb

# apt-file reads /var/lib/apt/lists at runtime, so the lists are kept

apt-file update

echo 'source /usr/share/modules/init/bash' >> /etc/bash.bashrc

rm -rf /home/ubuntu

# Package manifest: diff two of these to check that two builds are identical

dpkg-query -W -f='\${Package}\t\${Version}\t\${Architecture}\n' | sort > /packages.txt

apt-get clean
EOF

chmod +x apt.sh

cat -> singularity.def << EOF
Bootstrap: docker

From: $IMAGE

%files
  /usr/local/share/ca-certificates/meteo-fr.crt /usr/local/share/ca-certificates/meteo-fr.crt
  /usr/local/share/ca-certificates/proxy1.crt   /usr/local/share/ca-certificates/proxy1.crt
  singularity.def                               /singularity.def
  apt.sh                                        /apt.sh

%post
  /apt.sh

%environment
  export LANG=fr_FR.UTF-8
  export LANGUAGE=fr_FR:fr
  export LC_ALL=fr_FR.UTF-8

%labels
  Snapshot $SNAPSHOT
  BaseImage $IMAGE

EOF

export TMPDIR=$HOME/tmp
export SINGULARITY_TMPDIR=$HOME/tmp

singularity build --force --fakeroot singularity.sif singularity.def

singularity exec singularity.sif cat /packages.txt > singularity.packages.txt


exit 0
singularity build --fakeroot --sandbox singularity   singularity.def  # image dans un repertoire
singularity shell --fakeroot --writable singularity                   # root
singularity shell singularity                                         # marguina
singularity build --fakeroot singularity.sif singularity              # creer un .sif a partir du repertoire
