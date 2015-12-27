{{ __filename = __filename if package_boot else None }}
#!/bin/bash
set -e -x

apt-get update
apt-get upgrade -y
apt-get install -y git devscripts build-essential

{{ =include("../macosx-common.sh") }}

{{
	download("xz.tar.gz", "http://tukaani.org/xz/xz-5.2.2.tar.gz",
		     "73df4d5d34f0468bd57d09f2d8af363e95ed6cc3a4a86129d2f2c366259902a2")
}}

# ./configure fails to find the SHA256 darwin functions if dsymutil is not present
# and runs into a compiling issue as it mixes the system header files with it's own
# SA256 implementation. To prevent the following error, we can just create a stub
# as the extracted symbols are not used at all.
# check/sha256.c:121:32: error: no member named 'state' in 'struct CC_SHA256state_st'
(
  echo "#!/bin/bash"
  echo "echo \"dsymutil stub: \$@\" >&2"
) > /usr/bin/i686-apple-darwin12-dsymutil
chmod +x /usr/bin/i686-apple-darwin12-dsymutil


su builder -c "tar -xvf xz.tar.gz --strip-components 1"
rm xz.tar.gz

su builder -c "./configure --prefix=/usr --host i686-apple-darwin12"
cp /build/source/config.log /build/
su builder -c "make"
su builder -c "mkdir /build/tmp"
su builder -c "make install DESTDIR=/build/tmp/"
su builder -c "./fixup-import.py --destdir /build/tmp --verbose"
su builder -c "(cd /build/tmp/; tar -cvzf /build/xz-5.2.2-osx.tar.gz .)"
