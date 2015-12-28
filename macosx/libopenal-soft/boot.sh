{{ __filename = __filename if package_boot else None }}
#!/bin/bash
set -e -x

apt-get update
apt-get upgrade -y
apt-get install -y git devscripts build-essential cmake

{{ =include("../macosx-common.sh") }}

{{
	# We also need commit "Use Apple's pthread_setname_np before GNU's".
	download("libopenal-soft.tar.gz", "https://github.com/kcat/openal-soft/archive/bce20d1f6be43dcf3a5be0ec97b35cbe335844e7.tar.gz",
			 "aa0232ef47c278a52e8a58f676614400172520358440c2c79a24133b4cc046df")
}}

su builder -c "tar -xvf libopenal-soft.tar.gz --strip-components 1"
rm libopenal-soft.tar.gz

su builder -c "cat *.patch | patch -p1"

cd build
su builder -c "cmake -D CMAKE_INSTALL_PREFIX=/usr -D CMAKE_BUILD_TYPE=Release \
				-D CMAKE_TOOLCHAIN_FILE=../toolchain-i686-apple-darwin12.cmake ../"
cp /build/source/build/CMakeCache.txt /build/
su builder -c "make VERBOSE=1"
su builder -c "mkdir /build/tmp"
su builder -c "make install DESTDIR=/build/tmp/"
su builder -c "/build/source/fixup-import.py --destdir /build/tmp --verbose"
su builder -c "(cd /build/tmp/; tar -cvzf /build/libopenal-soft-1.17.1-osx.tar.gz .)"
