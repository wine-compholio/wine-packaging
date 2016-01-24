{{ __filename = __filename if package_boot else None }}
#!/bin/bash
set -e -x

apt-get update
apt-get upgrade -y
apt-get install -y git devscripts build-essential

{{
	url = "https://source.winehq.org/git/wine.git/snapshot"
	version = "master" if package_daily else "wine-%s" % package_version
	download("wine.tar.bz2", "%s/%s.tar.bz2" % (url, version), wine_sha)
}}
su builder -c "tar -xvf wine.tar.bz2 --strip-components 1"
rm wine.tar.bz2

{{ if staging }}
{{
	url = "https://github.com/wine-compholio/wine-staging/archive"
	# version = "master" if package_daily else "v%s" % package_version
	version = "f2d347b8977b371f2568f4959b291132eac8342f"
	download("wine-staging.tar.gz", "%s/%s.tar.gz" % (url, version), staging_sha)
}}
su builder -c "tar -xvf wine-staging.tar.gz --strip-components 1"
rm wine-staging.tar.gz
{{ endif }}

mk-build-deps -i -r -t "apt-get -y" debian/control
su builder -c "debuild -us -uc -b -j3"
