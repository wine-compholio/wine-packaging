#!/bin/bash
set -e -x

baseurl="http://http.debian.net/debian/pool/main/l/llvm-toolchain-3.8"

wget "$baseurl/llvm-toolchain-3.8_3.8.1-17.dsc"
wget "$baseurl/llvm-toolchain-3.8_3.8.1.orig-clang-tools-extra.tar.bz2"
wget "$baseurl/llvm-toolchain-3.8_3.8.1.orig-clang.tar.bz2"
wget "$baseurl/llvm-toolchain-3.8_3.8.1.orig-compiler-rt.tar.bz2"
wget "$baseurl/llvm-toolchain-3.8_3.8.1.orig-lldb.tar.bz2"
wget "$baseurl/llvm-toolchain-3.8_3.8.1.orig-polly.tar.bz2"
wget "$baseurl/llvm-toolchain-3.8_3.8.1.orig.tar.bz2"
wget "$baseurl/llvm-toolchain-3.8_3.8.1-17.debian.tar.xz"

sha256sum -c checksums

su builder -c "dpkg-source -x llvm-toolchain-3.8_3.8.1-17.dsc"

cd llvm-toolchain-3.8-3.8.1
su builder -c "cat ../*.patch | patch -p1"

mk-build-deps -i -r -t "apt-get -y" debian/control
su builder -c "DEB_BUILD_OPTIONS=nocheck debuild -us -uc -b -j3"
cd ..

mv *.deb ../output/
