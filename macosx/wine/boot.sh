{{ __filename = __filename if package_boot else None }}
#!/bin/bash
set -e -x

apt-get update
apt-get upgrade -y
apt-get install -y git devscripts build-essential

{{ =include("../macosx-common.sh") }}
tar --skip-old-files -C /build/macos-rootfs -xf /build/source/deps/xquartz-*.tar.xz
(
	tar -C /build/macos-rootfs -xvf /build/source/deps/libjpeg-turbo-*-osx.tar.gz
	tar -C /build/macos-rootfs -xvf /build/source/deps/libtiff-*-osx.tar.gz
	tar -C /build/macos-rootfs -xvf /build/source/deps/liblcms2-*-osx.tar.gz
	tar -C /build/macos-rootfs -xvf /build/source/deps/liblzma-*-osx.tar.gz
	tar -C /build/macos-rootfs -xvf /build/source/deps/libxml2-*-osx.tar.gz
	tar -C /build/macos-rootfs -xvf /build/source/deps/libxslt-*-osx.tar.gz
{{ if staging }}
	tar -C /build/macos-rootfs -xvf /build/source/deps/libtxc_dxtn_s2tc-*-osx.tar.gz
{{ endif }}
) > /build/source/deps/filelist.txt

# ./configure expects that dsymutil is present, although its not
# really used afterwards. Create a stub to make it happy. Fixes
# detection of multiple functions and build errors.
(
  echo "#!/bin/bash"
  echo "echo \"dsymutil stub: \$@\" >&2"
) > /usr/bin/i686-apple-darwin12-dsymutil
chmod +x /usr/bin/i686-apple-darwin12-dsymutil

{{
	url = "https://source.winehq.org/git/wine.git/snapshot"
	version = "master" if package_daily else "wine-%s" % package_version
	download("wine.tar.bz2", "%s/%s.tar.bz2" % (url, version))
}}
su builder -c "tar -xf wine.tar.bz2 --strip-components 1"
rm wine.tar.bz2

{{ if staging }}
{{
	url = "https://github.com/wine-compholio/wine-staging/archive"
	version = "master" if package_daily else "v%s" % package_version
	download("wine-staging.tar.gz", "%s/%s.tar.gz" % (url, version))
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
su builder -c "(cd /build/tmp/; tar -cvzf /build/{{ =compat_package }}-{{ =version }}-osx.tar.gz .)"
