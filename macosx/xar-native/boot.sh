{{ __filename = __filename if package_boot else None }}
#!/bin/bash
set -e -x

apt-get update
apt-get upgrade -y
apt-get install -y git devscripts build-essential

{{
	download("xar.tar.gz", "https://github.com/mackyle/xar/archive/66d451dab1ef859dd0c83995f2379335d35e53c9.tar.gz",
			 "891a1ee71369e535c9b302ab20fb94dac40fcf30f1951749e238334689454c02")
}}

su builder -c "tar -xvf xar.tar.gz --strip-components 1"
rm xar.tar.gz

cd xar
mk-build-deps -i -r -t "apt-get -y" debian/control
su builder -c "debuild -us -uc -b -j3"
cd ..
cp *.deb ../
