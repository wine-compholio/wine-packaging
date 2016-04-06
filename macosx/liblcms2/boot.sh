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
	tar -C /build/macos-rootfs -xvf /build/source/deps/libjpeg-turbo-*-osx64.tar.gz
	tar -C /build/macos-rootfs -xvf /build/source/deps/libtiff-*-osx64.tar.gz
) > /build/source/deps/filelist.txt

{{
	# FIXME: package_daily is ignored so far
	url = "http://downloads.sourceforge.net/sourceforge/lcms"
	download("liblcms2.tar.gz", "%s/lcms2-%s.tar.gz" % (url, package_version), sha)
}}

{{ for (host, arch) in [("i686-apple-darwin12", ""), ("x86_64-apple-darwin12", "64")] }}

su builder -c "mkdir build{{ =arch }}"
cd build{{ =arch }}
su builder -c "tar -xvf ../liblcms2.tar.gz --strip-components 1"

su builder -c "./configure --prefix=/usr --host {{ =host }}"
cp config.log /build/config{{ =arch }}.log
su builder -c "make -j3"
su builder -c "mkdir /build/tmp{{ =arch }}"
su builder -c "make install DESTDIR=/build/tmp{{ =arch }}/"
su builder -c "mkdir -p /build/tmp{{ =arch }}/usr/share/doc/liblcms2"
su builder -c "cp -a COPYING /build/tmp{{ =arch }}/usr/share/doc/liblcms2"
su builder -c "../fixup-import.py --destdir /build/tmp{{ =arch }} --filelist /build/source/deps/filelist.txt --verbose"

cd ..

{{ endfor }}

su builder -c "(cd /build/tmp; fakeroot tar -cvzf /build/{{ =output }}-osx.tar.gz .)"
su builder -c "./make-universal.py --dir32 /build/tmp --dir64 /build/tmp64"
su builder -c "(cd /build/tmp64; fakeroot tar -cvzf /build/{{ =output }}-osx64.tar.gz .)"