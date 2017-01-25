{{ __filename = __filename if package_boot else None }}
#!/bin/bash
set -e -x

dnf clean metadata
dnf upgrade -y

{{
	# FIXME: Fix support for daily builds - snapshot urls are no longer available
	url = "https://dl.winehq.org/wine/source"
	version = "%s/wine-%s" % (".".join(package_version.split("-")[0].split(".")[:2]), package_version)
	download("wine.tar.bz2", "%s/%s.tar.bz2" % (url, version), wine_sha)
}}

{{ if staging }}
{{
	url = "https://github.com/wine-compholio/wine-staging/archive"
	version = "master" if package_daily else "v%s" % package_version
	download("wine-staging.tar.gz", "%s/%s.tar.gz" % (url, version), staging_sha)
}}
{{ endif }}

# Generate directories for build
mkdir /home/builder/wine
cd /home/builder/wine
mkdir BUILD BUILDROOT RPMS SPECS SRPMS tmp

if [ "$(uname -m)" == "x86_64" ]; then
	sed -i "s/^%_lib .*$/%_lib lib64/g" /build/source/rpmmacros
fi

# Create symlinks
ln -s /build/source/rpmmacros /home/builder/.rpmmacros
ln -s /build RPMS/i686
ln -s /build RPMS/x86_64
ln -s /build RPMS/noarch
ln -s /build/source SOURCES
for _f in /build/source/*.spec; do
	ln -s "$_f" "SPECS/$(basename "$_f")"
done

# Fixup permissions
chown -R builder:builder /home/builder/wine

# Run builds
cd SPECS
for _f in *.spec; do
	dnf builddep -y "$_f"
	su builder -c "export BUILDER_TOPDIR=/home/builder/wine; rpmbuild -vv -bb \"$_f\""
done

# Check for missing build requirements
cd /build
for _f in *.rpm; do
	if rpm -qpR "$_f" | grep "wine-missing-buildrequires-"; then
		echo "Missing build requirements, package would be broken!" >&2
		exit 1
	fi
done
