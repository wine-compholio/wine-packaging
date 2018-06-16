#!/bin/bash
set -e -x

wget -O "bomutils.tar.gz" "https://github.com/hogliux/bomutils/archive/0.2.tar.gz"
echo "fb1f4ae37045eaa034ddd921ef6e16fb961e95f0364e5d76c9867bc8b92eb8a4  bomutils.tar.gz" | sha256sum -c

cd bomutils
su builder -c "tar -xvf ../bomutils.tar.gz --strip-components 1"
mk-build-deps -i -r -t "apt-get -y" debian/control
su builder -c "debuild -us -uc -b -j3"
cd ..

mv *.deb ../output/
