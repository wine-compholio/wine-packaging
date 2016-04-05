{{ __filename = __filename if package_boot else None }}
{{
	output = "%s-%s" % (package, package_version)
	output += "-%s" % package_release if package_release != "" else ""
}}
#!/bin/bash
set -e -x

apt-get update
apt-get upgrade -y
apt-get install -y git devscripts build-essential yasm automake

{{ =include("../macosx-common.sh") }}

{{
	url = "https://github.com/libjpeg-turbo/libjpeg-turbo/archive"
	version = "master" if package_daily else "%s" % package_version
	download("libjpeg-turbo.tar.gz", "%s/%s.tar.gz" % (url, version), sha)
}}

su builder -c "tar -xvf libjpeg-turbo.tar.gz --strip-components 1"
rm libjpeg-turbo.tar.gz

su builder -c "cat *.patch | patch -p1"
su builder -c "autoreconf -i"

{{ if is_64bit }}
su builder -c "./configure --prefix=/usr --host x86_64-apple-darwin12 --libdir=/usr/lib64"
{{ else }}
su builder -c "./configure --prefix=/usr --host i686-apple-darwin12"
{{ endif }}
cp /build/source/config.log /build/
su builder -c "make"
su builder -c "mkdir /build/tmp"
su builder -c "make install DESTDIR=/build/tmp/"
su builder -c "cp -a LICENSE.txt /build/tmp/usr/share/doc/libjpeg-turbo"
su builder -c "./fixup-import.py --destdir /build/tmp --verbose"
{{ if is_64bit }}
su builder -c "(cd /build/tmp; fakeroot tar -cvzf /build/{{ =output }}-osx64.tar.gz .)"
{{ else }}
su builder -c "(cd /build/tmp; fakeroot tar -cvzf /build/{{ =output }}-osx.tar.gz .)"
{{ endif }}
