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

{{
	# FIXME: package_daily is ignored so far
	url = "http://tukaani.org/xz"
	download("liblzma.tar.gz", "%s/xz-%s.tar.gz" % (url, package_version), sha)
}}

su builder -c "tar -xvf liblzma.tar.gz --strip-components 1"
rm liblzma.tar.gz

su builder -c "./configure --prefix=/usr --host i686-apple-darwin12"
cp /build/source/config.log /build/
su builder -c "make"
su builder -c "mkdir /build/tmp"
su builder -c "make install DESTDIR=/build/tmp/"
# "make install" already copies license files to usr/share/doc/xz
su builder -c "./fixup-import.py --destdir /build/tmp --verbose"
su builder -c "(cd /build/tmp; tar -cvzf /build/{{ =output }}-osx.tar.gz .)"
