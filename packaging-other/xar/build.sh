#!/bin/bash
set -e -x

wget -O "xar.tar.gz" "https://github.com/mackyle/xar/archive/66d451dab1ef859dd0c83995f2379335d35e53c9.tar.gz"
echo "891a1ee71369e535c9b302ab20fb94dac40fcf30f1951749e238334689454c02  xar.tar.gz" | sha256sum -c

su builder -c "tar -xf xar.tar.gz --strip-components 1"
su builder -c "cat *.patch | patch -p1"

cd xar
mk-build-deps -i -r -t "apt-get -y" debian/control
su builder -c "debuild -us -uc -b -j3"
cd ..

mv *.deb ../output/
