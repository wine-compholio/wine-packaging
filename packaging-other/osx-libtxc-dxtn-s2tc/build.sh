#!/bin/bash
set -e -x

export package="libtxc-dxtn-s2tc"
export version="1.0"
export commit="f6ec862d7594e29ae80a6e49f66ad4c76cf09abc"
export checksum="ec0b8082e97800b24659520443bebe60b60c692d6165c63d83f6fa128dffb87b"

apt-get install -y git devscripts build-essential

function get_source()
{
	set -e -x

	wget -O libtxc-dxtn-s2tc.tar.gz "https://github.com/divVerent/s2tc/archive/$commit.tar.gz"
	echo "$checksum  libtxc-dxtn-s2tc.tar.gz" | sha256sum -c
}

function build_arch()
{
	set -e -x

	arch="$1"
	host="$2"

	mkdir "build$arch"
	cd "build$arch"
	tar -xf ../libtxc-dxtn-s2tc.tar.gz --strip-components 1

	cat ../*.patch | patch -p1
	./autogen.sh

	./configure --prefix=/usr --host "$host"
	cp config.log "/build/output/config$arch.log"
	make -j3

	mkdir "/build/source/tmp$arch"
	make install DESTDIR="/build/source/tmp$arch"
	mkdir -p "/build/source/tmp$arch/usr/share/doc/libtxc_dxtn"
	cp -a COPYING "/build/source/tmp$arch/usr/share/doc/libtxc_dxtn/"

	fixup-import.py --destdir "/build/source/tmp$arch" --verbose
}

function create_pkg()
{
	set -e -x

	(cd /build/source/tmp32 && fakeroot tar -cvzf "/build/output/$package-$version-osx.tar.gz" .)
	make-universal.py --dir32 /build/source/tmp32 --dir64 /build/source/tmp64
	(cd /build/source/tmp64 && fakeroot tar -cvzf "/build/output/$package-$version-osx64.tar.gz" .)
}

export -f get_source build_arch create_pkg
su builder -c "get_source"
su builder -c "build_arch 32 i686-apple-darwin12"
su builder -c "build_arch 64 x86_64-apple-darwin12"
su builder -c "create_pkg"
