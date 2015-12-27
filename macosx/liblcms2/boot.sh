{{ __filename = __filename if package_boot else None }}
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

# ./configure expects that dsymutil is present, although its not
# really used afterwards. Create a stub to make it happy. Fixes
# "checking for jpeg_read_header in -ljpeg... no" and other similar
# errors.
(
  echo "#!/bin/bash"
  echo "echo \"dsymutil stub: \$@\" >&2"
) > /usr/bin/i686-apple-darwin12-dsymutil
chmod +x /usr/bin/i686-apple-darwin12-dsymutil

{{
	download("liblcms2.tar.gz", "http://downloads.sourceforge.net/sourceforge/lcms/lcms2-2.7.tar.gz",
			 "4524234ae7de185e6b6da5d31d6875085b2198bc63b1211f7dde6e2d197d6a53")
}}

su builder -c "tar -xvf liblcms2.tar.gz --strip-components 1"
rm liblcms2.tar.gz

su builder -c "./configure --prefix=/usr --host i686-apple-darwin12"
su builder -c "make"
su builder -c "mkdir /build/tmp"
su builder -c "make install DESTDIR=/build/tmp/"
su builder -c "./fixup-import.py --destdir /build/tmp --filelist /build/source/deps/filelist.txt --verbose"
su builder -c "(cd /build/tmp/; tar -cvzf /build/liblcms2-2.7-osx.tar.gz .)"
