#!/bin/bash
set -e -x

wget -O "cctools.tar.gz" "https://github.com/tpoechtrager/cctools-port/archive/8e9c3f2506b51cf56725eaa60b6e90e240e249ca.tar.gz"
echo "c413a0c29468518fa4980dd4fdf90f8ca13843d86df6041c22d38bd26358e512  cctools.tar.gz" | sha256sum -c

su builder -c "tar -xvf cctools.tar.gz --strip-components 1"

su builder -c "cat *.patch | patch -p1"
cd cctools
mk-build-deps -i -r -t "apt-get -y" debian/control
su builder -c "debuild -us -uc -b -j3"
cd ..

mv *.deb ../output/
