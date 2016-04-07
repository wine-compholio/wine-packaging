{{ __filename = __filename if package_boot else None }}
#!/bin/bash
set -e -x

apt-get update
apt-get upgrade -y
apt-get install -y git devscripts build-essential

{{ =include("../clang-common.sh") }}

{{
	download("cctools.tar.gz", "https://github.com/tpoechtrager/cctools-port/archive/5467d1afcc18632ad4dc6410ce46dd26f39868f7.tar.gz",
			 "ceee4980f3e217277fbcf26ac52ccc53069b7f7238f5cede1725ecca201be6ee")
}}

su builder -c "tar -xvf cctools.tar.gz --strip-components 1"
rm cctools.tar.gz

su builder -c "cat *.patch | patch -p1"
cd cctools
mk-build-deps -i -r -t "apt-get -y" debian/control
su builder -c "debuild -us -uc -b -j3"
cd ..
mv *.deb ../
