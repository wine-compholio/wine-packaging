#!/bin/bash
set -e -x

export package="libtiff"
export version="4.0.7"
export depends=(liblzma libjpeg-turbo)
export checksum="9f43a2cfb9589e5cecaa66e16bf87f814c945f22df7ba600d63aac4632c4f019"

apt-get install -y git devscripts build-essential
install-dep.py --universal "${depends[@]}"

function get_source()
{
	set -e -x

	wget -O libtiff.tar.gz "http://download.osgeo.org/libtiff/tiff-$version.tar.gz"
	echo "$checksum  libtiff.tar.gz" | sha256sum -c
}

function build_arch()
{
	set -e -x

	arch="$1"
	host="$2"

	mkdir "build$arch"
	cd "build$arch"
	tar -xf ../libtiff.tar.gz --strip-components 1

	./configure --prefix=/usr --host "$host"
	cp config.log "/build/output/config$arch.log"
	make -j3

	mkdir "/build/source/tmp$arch"
	make install DESTDIR="/build/source/tmp$arch"

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
