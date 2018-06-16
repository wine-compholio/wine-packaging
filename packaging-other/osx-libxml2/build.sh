#!/bin/bash
set -e -x

export package="libxml2"
export version="2.9.4"
export depends=(liblzma)
export checksum="ffb911191e509b966deb55de705387f14156e1a56b21824357cdf0053233633c"

apt-get install -y git devscripts build-essential
install-dep.py --universal "${depends[@]}"

function get_source()
{
	set -e -x

	wget -O libxml2.tar.gz "ftp://xmlsoft.org/libxml2/libxml2-$version.tar.gz"
	echo "$checksum  libxml2.tar.gz" | sha256sum -c
}

function build_arch()
{
	set -e -x

	arch="$1"
	host="$2"

	mkdir "build$arch"
	cd "build$arch"
	tar -xf ../libxml2.tar.gz --strip-components 1

	./configure --prefix=/usr --host "$host" --without-python
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
