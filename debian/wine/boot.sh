{{ __filename = __filename if package_boot else None }}
#!/bin/bash
set -e -x

apt-get update
apt-get upgrade -y
apt-get install -y git devscripts build-essential

{{
	# FIXME: Fix support for daily builds - snapshot urls are no longer available
	url = "https://dl.winehq.org/wine/source/2.x"
	download("wine.tar.xz", "%s/wine-%s.tar.xz" % (url, package_version), wine_sha)
}}
su builder -c "tar -xvf wine.tar.xz --strip-components 1"
rm wine.tar.xz

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
