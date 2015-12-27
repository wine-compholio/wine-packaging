{{ __filename = __filename if package_boot else None }}
#!/bin/bash
set -e -x

apt-get update
apt-get upgrade -y
apt-get install -y git devscripts build-essential

{{ =include("../macosx-common.sh") }}
(
	tar -C /build/macos-rootfs -xvf /build/source/deps/libxml2-*-osx.tar.gz
) > /build/source/deps/filelist.txt

# ./configure expects that dsymutil is present, although its not
# really used afterwards. Create a stub to make it happy. Fixes
# detection of multiple functions.
(
  echo "#!/bin/bash"
  echo "echo \"dsymutil stub: \$@\" >&2"
) > /usr/bin/i686-apple-darwin12-dsymutil
chmod +x /usr/bin/i686-apple-darwin12-dsymutil

{{
	download("libxslt.tar.gz", "http://xmlsoft.org/sources/libxslt-1.1.28.tar.gz",
		     "5fc7151a57b89c03d7b825df5a0fae0a8d5f05674c0e7cf2937ecec4d54a028c")
}}

su builder -c "tar -xvf libxslt.tar.gz --strip-components 1"
rm libxslt.tar.gz

su builder -c "./configure --prefix=/usr --host i686-apple-darwin12"
cp /build/source/config.log /build/
su builder -c "make"
su builder -c "mkdir /build/tmp"
su builder -c "make install DESTDIR=/build/tmp/"
su builder -c "./fixup-import.py --destdir /build/tmp --filelist /build/source/deps/filelist.txt --verbose"
su builder -c "(cd /build/tmp/; tar -cvzf /build/libxslt-1.1.28-osx.tar.gz .)"
