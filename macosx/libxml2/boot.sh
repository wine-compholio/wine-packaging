{{ __filename = __filename if package_boot else None }}
#!/bin/bash
set -e -x

apt-get update
apt-get upgrade -y
apt-get install -y git devscripts build-essential

{{ =include("../macosx-common.sh") }}
(
	tar -C /build/macos-rootfs -xvf /build/source/deps/liblzma-*-osx.tar.gz
) > /build/source/deps/filelist.txt

# ./configure expects that dsymutil is present, although its not
# really used afterwards. Create a stub to make it happy. Fixes
# detection of multiple functions and build errors.
(
  echo "#!/bin/bash"
  echo "echo \"dsymutil stub: \$@\" >&2"
) > /usr/bin/i686-apple-darwin12-dsymutil
chmod +x /usr/bin/i686-apple-darwin12-dsymutil

{{
	download("libxml2.tar.gz", "ftp://xmlsoft.org/libxml2/libxml2-2.9.3.tar.gz",
		     "4de9e31f46b44d34871c22f54bfc54398ef124d6f7cafb1f4a5958fbcd3ba12d")
}}

su builder -c "tar -xvf libxml2.tar.gz --strip-components 1"
rm libxml2.tar.gz

# ./configure detects Python installed in the host system, but not
# all build dependencies are installed in the MacOS rootfs.
su builder -c "./configure --prefix=/usr --host i686-apple-darwin12 --without-python"
cp /build/source/config.log /build/
su builder -c "make"
su builder -c "mkdir /build/tmp"
su builder -c "make install DESTDIR=/build/tmp/"
su builder -c "./fixup-import.py --destdir /build/tmp --filelist /build/source/deps/filelist.txt --verbose"
su builder -c "(cd /build/tmp/; tar -cvzf /build/libxml2-2.9.3-osx.tar.gz .)"
