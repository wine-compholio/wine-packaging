{{ __filename = __filename if package_boot else None }}
#!/bin/bash
set -e -x

apt-get update
apt-get upgrade -y
apt-get install -y git devscripts build-essential

{{
	# FIXME: Fix support for daily builds - snapshot urls are no longer available
	url = "https://dl.winehq.org/wine/source"
	version = "%s/wine-%s" % (".".join(package_version.split("-")[0].split(".")[:2]), package_version)
	download("wine.tar.bz2", "%s/%s.tar.bz2" % (url, version), wine_sha)
}}
su builder -c "tar -xvf wine.tar.bz2 --strip-components 1"
rm wine.tar.bz2

{{ if staging }}
{{
	url = "https://github.com/wine-compholio/wine-staging/archive"
	version = "master" if package_daily else "v%s" % package_version
	download("wine-staging.tar.gz", "%s/%s.tar.gz" % (url, version), staging_sha)
}}
su builder -c "tar -xvf wine-staging.tar.gz --strip-components 1"
rm wine-staging.tar.gz
{{ endif }}

mk-build-deps -i -r -t "apt-get -y" debian/control
su builder -c "debuild --no-lintian -us -uc -b -j3"
