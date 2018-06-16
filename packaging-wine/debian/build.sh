#!/bin/bash
set -e -x

cd wine
mk-build-deps -i -r -t "apt-get -y" debian/control
su builder -c "debuild --no-lintian -us -uc -b -j3"
cd ..

mv *.deb ../output/
