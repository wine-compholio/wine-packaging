#!/bin/bash
set -e -x

export package="libjpeg-turbo"
export version="1.5.1"
export checksum="c15a9607892113946379ccea3ca8b85018301b200754f209453ab21674268e77"

apt-get install -y git devscripts build-essential yasm automake

function get_source()
{
	set -e -x

	wget -O libjpeg-turbo.tar.gz "https://github.com/libjpeg-turbo/libjpeg-turbo/archive/$version.tar.gz"
	echo "$checksum  libjpeg-turbo.tar.gz" | sha256sum -c
}

function build_arch()
{
	set -e -x

	arch="$1"
	host="$2"

	mkdir "build$arch"
	cd "build$arch"
	tar -xf ../libjpeg-turbo.tar.gz --strip-components 1

	cat ../*.patch | patch -p1
	autoreconf -i

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
