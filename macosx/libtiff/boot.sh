{{ __filename = __filename if package_boot else None }}
#!/bin/bash
set -e -x

apt-get update
apt-get upgrade -y
apt-get install -y git devscripts build-essential

{{ =include("../macosx-common.sh") }}
(
	tar -C /build/macos-rootfs -xvf /build/source/deps/libjpeg-turbo-*-osx.tar.gz
	tar -C /build/macos-rootfs -xvf /build/source/deps/liblzma-*-osx.tar.gz
) > /build/source/deps/filelist.txt

{{
	download("libtiff.tar.gz", "http://download.osgeo.org/libtiff/tiff-4.0.6.tar.gz",
		     "4d57a50907b510e3049a4bba0d7888930fdfc16ce49f1bf693e5b6247370d68c")
}}

su builder -c "tar -xvf libtiff.tar.gz --strip-components 1"
rm libtiff.tar.gz

su builder -c "./configure --prefix=/usr --host i686-apple-darwin12"
cp /build/source/config.log /build/
su builder -c "make"
su builder -c "mkdir /build/tmp"
su builder -c "make install DESTDIR=/build/tmp/"
su builder -c "./fixup-import.py --destdir /build/tmp --filelist /build/source/deps/filelist.txt --verbose"
su builder -c "(cd /build/tmp/; tar -cvzf /build/libtiff-4.0.6-osx.tar.gz .)"
