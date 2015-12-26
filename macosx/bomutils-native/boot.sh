{{ __filename = __filename if package_boot else None }}
#!/bin/bash
set -e -x

apt-get update
apt-get upgrade -y
apt-get install -y git devscripts build-essential

{{
	download("bomutils.tar.gz", "https://github.com/hogliux/bomutils/archive/0.2.tar.gz",
			 "fb1f4ae37045eaa034ddd921ef6e16fb961e95f0364e5d76c9867bc8b92eb8a4")
}}

su builder -c "tar -xvf bomutils.tar.gz --strip-components 1"
rm bomutils.tar.gz

mk-build-deps -i -r -t "apt-get -y" debian/control
su builder -c "debuild -us -uc -b -j3"
