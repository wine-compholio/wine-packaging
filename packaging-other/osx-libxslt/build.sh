#!/bin/bash
set -e -x

export package="libxslt"
export version="1.1.29"
export depends=(liblzma libxml2)
export checksum="b5976e3857837e7617b29f2249ebb5eeac34e249208d31f1fbf7a6ba7a4090ce"

apt-get install -y git devscripts build-essential
install-dep.py --universal "${depends[@]}"

function get_source()
{
	set -e -x

	wget -O libxslt.tar.gz "ftp://xmlsoft.org/libxslt/libxslt-$version.tar.gz"
	echo "$checksum  libxslt.tar.gz" | sha256sum -c
}

function build_arch()
{
	set -e -x

	arch="$1"
	host="$2"

	mkdir "build$arch"
	cd "build$arch"
	tar -xf ../libxslt.tar.gz --strip-components 1

	cat ../*.patch | patch -p1
	autoreconf -i

	./configure --prefix=/usr --host "$host" --without-python
	cp config.log "/build/output/config$arch.log"
	make -j3

	mkdir "/build/source/tmp$arch"
	make install DESTDIR="/build/source/tmp$arch"
	cp -a Copyright "/build/source/tmp$arch/usr/share/doc"/libxslt-*/

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
