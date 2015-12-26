{{ __filename = __filename if package_boot else None }}
#!/bin/bash
set -e -x

apt-get update
apt-get upgrade -y
apt-get install -y git devscripts build-essential nasm automake

{{ =include("../macosx-common.sh") }}

# ./configure expects that dsymutil is present, although its not
# really used afterwards. Create a stub to make it happy.
(
  echo "#!/bin/bash"
  echo "echo \"dsymutil stub: \$@\" >&2"
) > /usr/bin/i686-apple-darwin12-dsymutil
chmod +x /usr/bin/i686-apple-darwin12-dsymutil

{{
	download("libtiff.tar.gz", "http://download.osgeo.org/libtiff/tiff-4.0.6.tar.gz",
		     "4d57a50907b510e3049a4bba0d7888930fdfc16ce49f1bf693e5b6247370d68c")
}}

su builder -c "tar -xvf libtiff.tar.gz --strip-components 1"
rm libtiff.tar.gz

su builder -c "./configure --prefix=/usr --host i686-apple-darwin12"
su builder -c "make"
su builder -c "mkdir /build/tmp"
su builder -c "make install DESTDIR=/build/tmp/"
su builder -c "(cd /build/tmp/; tar -cvzf /build/libtiff-4.0.6-osx.tar.gz .)"
