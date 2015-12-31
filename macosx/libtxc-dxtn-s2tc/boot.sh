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
	url = "https://github.com/divVerent/s2tc/archive"
	version = "master" if package_daily else "v%s" % package_version
	version = "e0dcdcb802c81e2ac4b1b49a2b39c984fb8f3604" # HACK
	download("libtxc-dxtn-s2tc.tar.gz", "%s/%s.tar.gz" % (url, version), sha)
}}

su builder -c "tar -xvf libtxc-dxtn-s2tc.tar.gz --strip-components 1"
rm libtxc-dxtn-s2tc.tar.gz

su builder -c "cat *.patch | patch -p1"
su builder -c "./autogen.sh"

su builder -c "./configure --prefix=/usr --host i686-apple-darwin12"
cp /build/source/config.log /build/
su builder -c "make"
su builder -c "mkdir /build/tmp"
su builder -c "make install DESTDIR=/build/tmp/"
su builder -c "mkdir -p /build/tmp/usr/share/doc/libtxc_dxtn"
su builder -c "cp -a COPYING /build/tmp/usr/share/doc/libtxc_dxtn"
su builder -c "./fixup-import.py --destdir /build/tmp --verbose"
su builder -c "(cd /build/tmp; fakeroot tar -cvzf /build/{{ =output }}-osx.tar.gz .)"
