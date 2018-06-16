#!/bin/bash
set -e -x

export package="liblcms2"
export version="2.8"
export depends=(liblzma libjpeg-turbo libtiff)
export checksum="66d02b229d2ea9474e62c2b6cd6720fde946155cd1d0d2bffdab829790a0fb22"

apt-get install -y git devscripts build-essential nasm automake
install-dep.py --universal "${depends[@]}"

function get_source()
{
	set -e -x

	wget -O lcms2.tar.gz "https://downloads.sourceforge.net/project/lcms/lcms/$version/lcms2-$version.tar.gz"
	echo "$checksum  lcms2.tar.gz" | sha256sum -c
}

function build_arch()
{
	set -e -x

	arch="$1"
	host="$2"

	mkdir "build$arch"
	cd "build$arch"
	tar -xf ../lcms2.tar.gz --strip-components 1

	./configure --prefix=/usr --host "$host"
	cp config.log "/build/output/config$arch.log"
	make -j3

	mkdir "/build/source/tmp$arch"
	make install DESTDIR="/build/source/tmp$arch"
	mkdir -p "/build/source/tmp$arch/usr/share/doc/liblcms2"
	cp -a COPYING "/build/source/tmp$arch/usr/share/doc/liblcms2"

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
