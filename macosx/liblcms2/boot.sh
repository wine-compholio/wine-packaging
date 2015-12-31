{{ __filename = __filename if package_boot else None }}
{{
	output = "%s-%s" % (package, package_version)
	output += "-%s" % package_release if package_release != "" else ""
}}
#!/bin/bash
set -e -x

apt-get update
apt-get upgrade -y
apt-get install -y git devscripts build-essential nasm automake

{{ =include("../macosx-common.sh") }}
(
	tar -C /build/macos-rootfs -xvf /build/source/deps/libjpeg-turbo-*-osx.tar.gz
	tar -C /build/macos-rootfs -xvf /build/source/deps/libtiff-*-osx.tar.gz
) > /build/source/deps/filelist.txt

{{
	# FIXME: package_daily is ignored so far
	url = "http://downloads.sourceforge.net/sourceforge/lcms"
	download("liblcms2.tar.gz", "%s/lcms2-%s.tar.gz" % (url, package_version), sha)
}}

su builder -c "tar -xvf liblcms2.tar.gz --strip-components 1"
rm liblcms2.tar.gz

su builder -c "./configure --prefix=/usr --host i686-apple-darwin12"
cp /build/source/config.log /build/
su builder -c "make"
su builder -c "mkdir /build/tmp"
su builder -c "make install DESTDIR=/build/tmp/"
su builder -c "mkdir -p /build/tmp/usr/share/doc/liblcms2"
su builder -c "cp -a COPYING /build/tmp/usr/share/doc/liblcms2"
su builder -c "./fixup-import.py --destdir /build/tmp --filelist /build/source/deps/filelist.txt --verbose"
su builder -c "(cd /build/tmp; tar -cvzf /build/{{ =output }}-osx.tar.gz .)"
