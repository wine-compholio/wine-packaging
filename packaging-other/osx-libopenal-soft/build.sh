#!/bin/bash
set -e -x

export package="libopenal-soft"
export version="1.17.2"
export checksum="a341f8542f1f0b8c65241a17da13d073f18ec06658e1a1606a8ecc8bbc2b3314"

apt-get install -y git devscripts build-essential cmake

function get_source()
{
	set -e -x

	wget -O libopenal-soft.tar.bz2 "http://kcat.strangesoft.net/openal-releases/openal-soft-$version.tar.bz2"
	echo "$checksum  libopenal-soft.tar.bz2" | sha256sum -c
}

function build_arch()
{
	set -e -x

	arch="$1"
	host="$2"

	mkdir "build$arch"
	cd "build$arch"
	tar -xf ../libopenal-soft.tar.bz2 --strip-components 1
	cat ../*.patch | patch -p1

	cd build

	cmake -D CMAKE_INSTALL_PREFIX=/usr -D CMAKE_INSTALL_NAME_DIR=/usr/lib \
				-D CMAKE_BUILD_TYPE=Release \
				-D CMAKE_TOOLCHAIN_FILE="../../toolchain-$host.cmake" ../
	cp CMakeCache.txt "/build/output/CMakeCache$arch.txt"
	make VERBOSE=1

	mkdir "/build/source/tmp$arch"
	make install DESTDIR="/build/source/tmp$arch"
	mkdir -p "/build/source/tmp$arch/usr/share/doc/openal-soft"
	cp -a ../COPYING "/build/source/tmp$arch/usr/share/doc/openal-soft/"

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
