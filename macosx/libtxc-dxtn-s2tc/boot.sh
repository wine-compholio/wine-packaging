{{ __filename = __filename if package_boot else None }}
#!/bin/bash
set -e -x

apt-get update
apt-get upgrade -y
apt-get install -y git devscripts build-essential

{{ =include("../macosx-common.sh") }}

{{
	download("libtxc_dxtn_s2tc.tar.gz", "https://github.com/divVerent/s2tc/archive/e0dcdcb802c81e2ac4b1b49a2b39c984fb8f3604.tar.gz",
		     "6de218388bb371c279b8e0069598b946e173ae6ca300bf14ec199ff04d5f57f4")
}}

su builder -c "tar -xvf libtxc_dxtn_s2tc.tar.gz --strip-components 1"
rm libtxc_dxtn_s2tc.tar.gz

su builder -c "cat *.patch | patch -p1"
su builder -c "./autogen.sh"

su builder -c "./configure --prefix=/usr --host i686-apple-darwin12"
cp /build/source/config.log /build/
su builder -c "make"
su builder -c "mkdir /build/tmp"
su builder -c "make install DESTDIR=/build/tmp/"
su builder -c "./fixup-import.py --destdir /build/tmp --verbose"
su builder -c "(cd /build/tmp/; tar -cvzf /build/libtxc_dxtn_s2tc-1.0-osx.tar.gz .)"
