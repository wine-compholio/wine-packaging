#!/bin/bash
set -e -x

export package="liblzma"
export version="5.2.3"
export checksum="71928b357d0a09a12a4b4c5fafca8c31c19b0e7d3b8ebb19622e96f26dbf28cb"

apt-get install -y git devscripts build-essential

function get_source()
{
	set -e -x

	wget -O liblzma.tar.gz "http://tukaani.org/xz/xz-$version.tar.gz"
	echo "$checksum  liblzma.tar.gz" | sha256sum -c
}

function build_arch()
{
	set -e -x

	arch="$1"
	host="$2"

	mkdir "build$arch"
	cd "build$arch"
	tar -xf ../liblzma.tar.gz --strip-components 1

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
