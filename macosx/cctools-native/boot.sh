{{ __filename = __filename if package_boot else None }}
#!/bin/bash
set -e -x

apt-get update
apt-get upgrade -y
apt-get install -y git devscripts build-essential

{{ =include("../clang-common.sh") }}

{{
	download("cctools.tar.gz", "https://github.com/tpoechtrager/cctools-port/archive/7d405492b09fa27546caaa989b8493829365deab.tar.gz")
}}

su builder -c "tar -xvf cctools.tar.gz --strip-components 1"
rm cctools.tar.gz

cd cctools
mk-build-deps -i -r -t "apt-get -y" debian/control
su builder -c "debuild -us -uc -b -j3"
cd ..
mv *.deb ../
