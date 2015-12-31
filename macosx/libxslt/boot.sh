{{ __filename = __filename if package_boot else None }}
{{
	output = "%s-%s" % (package, package_version)
	output += "-%s" % package_release if package_release != "" else ""
}}
#!/bin/bash
set -e -x

apt-get update
apt-get upgrade -y
apt-get install -y git devscripts build-essential

{{ =include("../macosx-common.sh") }}
(
	tar -C /build/macos-rootfs -xvf /build/source/deps/libxml2-*-osx.tar.gz
) > /build/source/deps/filelist.txt

{{
	# FIXME: package_daily is ignored so far
	url = "http://xmlsoft.org/sources"
	download("libxslt.tar.gz", "%s/libxslt-%s.tar.gz" % (url, package_version), sha)
}}

su builder -c "tar -xvf libxslt.tar.gz --strip-components 1"
rm libxslt.tar.gz

su builder -c "./configure --prefix=/usr --host i686-apple-darwin12"
cp /build/source/config.log /build/
su builder -c "make"
su builder -c "mkdir /build/tmp"
su builder -c "make install DESTDIR=/build/tmp/"
su builder -c "cp -a Copyright /build/tmp/usr/share/doc/libxslt-{{ =package_version }}"
su builder -c "./fixup-import.py --destdir /build/tmp --filelist /build/source/deps/filelist.txt --verbose"
su builder -c "(cd /build/tmp; fakeroot tar -cvzf /build/{{ =output }}-osx.tar.gz .)"
