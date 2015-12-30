{{ __filename = __filename if package_boot else None }}
#!/bin/bash
set -e -x

apt-get update
apt-get upgrade -y
apt-get install -y git devscripts build-essential python-magic python-lxml

{{ =include("../macosx-common.sh") }}
tar --skip-old-files -C /build/macos-rootfs -xf /build/source/deps/xquartz-*.tar.xz
(
	tar -C /build/macos-rootfs -xvf /build/source/deps/libjpeg-turbo-*-osx.tar.gz
	tar -C /build/macos-rootfs -xvf /build/source/deps/liblcms2-*-osx.tar.gz
	tar -C /build/macos-rootfs -xvf /build/source/deps/liblzma-*-osx.tar.gz
	tar -C /build/macos-rootfs -xvf /build/source/deps/libopenal-soft-*-osx.tar.gz
	tar -C /build/macos-rootfs -xvf /build/source/deps/libtiff-*-osx.tar.gz
	tar -C /build/macos-rootfs -xvf /build/source/deps/libxml2-*-osx.tar.gz
	tar -C /build/macos-rootfs -xvf /build/source/deps/libxslt-*-osx.tar.gz
{{ if staging }}
	tar -C /build/macos-rootfs -xvf /build/source/deps/libtxc-dxtn-s2tc-*-osx.tar.gz
{{ endif }}
) > /build/source/deps/filelist.txt

{{
	url = "https://source.winehq.org/git/wine.git/snapshot"
	sha = None if package_daily else wine_sha
	version = "master" if package_daily else "wine-%s" % package_version
	download("wine.tar.bz2", "%s/%s.tar.bz2" % (url, version), sha)
}}
su builder -c "tar -xf wine.tar.bz2 --strip-components 1"
rm wine.tar.bz2

{{ if staging }}
{{
	url = "https://github.com/wine-compholio/wine-staging/archive"
	sha = None if package_daily else staging_sha
	version = "master" if package_daily else "v%s" % package_version
	download("wine-staging.tar.gz", "%s/%s.tar.gz" % (url, version), sha)
}}
su builder -c "tar -xf wine-staging.tar.gz --strip-components 1"
rm wine-staging.tar.gz
make -C "patches" DESTDIR="$(pwd)" install
{{ endif }}

# FIXME: We don't explicitly install dependencies for the host system yet,
# however they should not matter as long as ./configure finishes successfully.

# Build tools
su builder -c "mkdir /build/wine-tools"
cd /build/wine-tools
su builder -c "../source/configure"
cp /build/wine-tools/config.log /build/config-tools.log
su builder -c "make __tooldeps__ -j3"

# Build for OSX
su builder -c "mkdir /build/wine-cross"
cd /build/wine-cross
su builder -c "../source/configure --prefix=/usr --host i686-apple-darwin12 --with-wine-tools=../wine-tools \
				--x-includes=/build/macos-rootfs/opt/X11/include --x-libraries=/build/macos-rootfs/opt/X11/lib \
				LDFLAGS='-Wl,-rpath,/opt/x11/lib'"
cp /build/wine-cross/config.log /build/config-cross.log
su builder -c "make -j3"
su builder -c "mkdir /build/tmp"
su builder -c "make install DESTDIR=/build/tmp/"
su builder -c "/build/source/fixup-import.py --destdir /build/tmp --filelist /build/source/deps/filelist.txt --verbose"
{{ version = package_version + ("-%s" % package_release if package_release != "" else "") }}
su builder -c "(cd /build/tmp; tar -cvzf /build/{{ =compat_package }}-{{ =version }}-osx.tar.gz .)"

# Install dependencies in DESTDIR
su builder -c "tar -C /build/tmp -xf /build/source/deps/libjpeg-turbo-*-osx.tar.gz"
su builder -c "tar -C /build/tmp -xf /build/source/deps/liblcms2-*-osx.tar.gz"
su builder -c "tar -C /build/tmp -xf /build/source/deps/liblzma-*-osx.tar.gz"
su builder -c "tar -C /build/tmp -xf /build/source/deps/libopenal-soft-*-osx.tar.gz"
su builder -c "tar -C /build/tmp -xf /build/source/deps/libtiff-*-osx.tar.gz"
su builder -c "tar -C /build/tmp -xf /build/source/deps/libxml2-*-osx.tar.gz"
su builder -c "tar -C /build/tmp -xf /build/source/deps/libxslt-*-osx.tar.gz"
{{ if staging }}
su builder -c "tar -C /build/tmp -xf /build/source/deps/libtxc-dxtn-s2tc-*-osx.tar.gz"
{{ endif }}
su builder -c "(cd /build/tmp; tar -cvzf /build/{{ =compat_package }}-portable-{{ =version }}-osx.tar.gz .)"

# Create payload directory
su builder -c "cp -ar /build/source/osx-package/payload-wine /build/tmp-osx-payload"
su builder -c "cp -ar /build/tmp/usr /build/tmp-osx-payload/Contents/wine"

# Assemble package
cd /build/source/osx-package
su builder -c "mkdir /build/tmp-osx-pkg"
su builder -c "./osx-package.py -C /build/tmp-osx-pkg init"

su builder -c "./osx-package.py -C /build/tmp-osx-pkg resources \
				--add /build/source/osx-package/resources"

su builder -c "./osx-package.py -C /build/tmp-osx-pkg settings \
				--title '{{ =package }} Installer' \
				--welcome 'welcome.html' \
				--architecture i386 x86_64 \
				--allow-customization false \
				--allow-external-scripts false \
				--target-any-volume true \
				--target-user-home true \
				--target-local-system true \
				--script /build/source/osx-package/install-script \
				--installation-check 'pm_install_check();'"

su builder -c "./osx-package.py -C /build/tmp-osx-pkg pkg-add \
				--identifier org.winehq.{{ =package }} \
				--version {{ =version }} \
				--install-location '/Applications/{{ =package }}.app' \
				--payload /build/tmp-osx-payload"

su builder -c "./osx-package.py -C /build/tmp-osx-pkg choice-add \
				--id choice1 \
				--title '{{ =package }}' \
				--description 'Installs {{ =package }}' \
				--pkgs org.winehq.{{ =package }}"

su builder -c "./osx-package.py -C /build/tmp-osx-pkg generate \
				--output /build/{{ =compat_package }}-{{ =version }}.pkg"
