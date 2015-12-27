{{ __filename = __filename if package_boot else None }}
#!/bin/bash
set -e -x

apt-get update
apt-get upgrade -y
apt-get install -y git devscripts build-essential nasm automake

{{ =include("../macosx-common.sh") }}

# ./configure expects that dsymutil is present, although its not
# really used afterwards. Create a stub to make it happy. Fixes
# "checking for -force_load linker flag... no" and other similar
# errors.
(
  echo "#!/bin/bash"
  echo "echo \"dsymutil stub: \$@\" >&2"
) > /usr/bin/i686-apple-darwin12-dsymutil
chmod +x /usr/bin/i686-apple-darwin12-dsymutil

{{
	download("libjpeg-turbo.tar.gz", "https://github.com/libjpeg-turbo/libjpeg-turbo/archive/1.4.2.tar.gz",
		     "7b5e45fbbe9ccb7ae25b4969d663ff5d837a5d8e83956bfadedcd31bd9756599")
}}

su builder -c "tar -xvf libjpeg-turbo.tar.gz --strip-components 1"
rm libjpeg-turbo.tar.gz

su builder -c "cat *.patch | patch -p1"
su builder -c "autoreconf -i"

su builder -c "./configure --prefix=/usr --host i686-apple-darwin12"
cp /build/source/config.log /build/
su builder -c "make"
su builder -c "mkdir /build/tmp"
su builder -c "make install DESTDIR=/build/tmp/"
su builder -c "./fixup-import.py --destdir /build/tmp --verbose"
su builder -c "(cd /build/tmp/; tar -cvzf /build/libjpeg-turbo-1.4.2-osx.tar.gz .)"
