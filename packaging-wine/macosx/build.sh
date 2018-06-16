#!/bin/bash
set -e -x

export package="{{ =macosx_package_name }}"
export version="{{ =macosx_package_version }}"
export depends=(libjpeg-turbo liblcms2 liblzma libopenal libtiff libxml2 libxslt)

{{ if staging }}
depends+=(libtxc-dxtn-s2tc)
{{ endif }}

apt-get install -y git devscripts build-essential python-magic python-lxml
tar --no-same-owner --skip-old-files -C /build/macos-rootfs -xf /build/deps/macosx/xquartz-2.7.7.tar.xz
install-dep.py --universal "${depends[@]}"

function build_tools()
{
	set -e -x

	# FIXME: We don't explicitly install dependencies for the host system yet,
	# however they should not matter as long as ./configure finishes successfully.

	mkdir "build-tools"
	cd "build-tools"
	../wine/configure --enable-win64
	cp config.log "/build/output/config-tools.log"
	make __tooldeps__ -j3
}

function build_arch()
{
	set -e -x

	arch="$1"
	host="$2"
	flag="$3"

	mkdir "build$arch"
	cd "build$arch"
	../wine/configure --prefix=/usr --host "$host" --with-wine-tools=../build-tools \
				--x-includes=/build/macos-rootfs/opt/X11/include \
				--x-libraries=/build/macos-rootfs/opt/X11/lib \
{{ if not enable_tests }}
				--disable-tests \
{{ endif }}
				"$flag" LDFLAGS='-Wl,-rpath,/opt/x11/lib' CFLAGS='-msse2 -O2'
	cp config.log "/build/output/config$arch.log"
	make -j3

	mkdir "/build/source/tmp$arch"
	make install DESTDIR="/build/source/tmp$arch"
	mkdir -p "/build/source/tmp$arch/usr/share/doc/wine"
	cp -a "/build/source/wine"/{ANNOUNCE,LICENSE,COPYING.*} "/build/source/tmp$arch/usr/share/doc/wine"

	fixup-import.py --destdir "/build/source/tmp$arch" --verbose
	fixup-import.py --destdir "/build/source/tmp$arch" --install_name --verbose
}

function create_pkg()
{
	set -e -x
	depends=("$@")

	# It wouldn't make sense to use make-universal here. Wine packages differ for 32-bit and 64-bit.
	# (cd /build/source/tmp32 && fakeroot tar -cvzf "/build/output/$package-$version-osx.tar.gz" .)
	# (cd /build/source/tmp64 && fakeroot tar -cvzf "/build/output/$package-$version-osx64.tar.gz" .)

	# Unpack dependencies
	mkdir /build/source/dep{,32,64}
	install-dep.py --destdir /build/source/dep32 --filelist /dev/null "${depends[@]}"
	install-dep.py --universal --destdir /build/source/dep --filelist /dev/null "${depends[@]}"
	fixup-import.py --destdir /build/source/dep32 --install_name --verbose
	fixup-import.py --destdir /build/source/dep --install_name --verbose

	# We need to create symlinks from lib64 -> lib
	# Our dependencies are universal binaries but
	# Wine64 only searches in PREFIX/lib64.
	mkdir -p /build/source/dep64/usr/lib64
	(cd /build/source/dep/usr/lib && for lib in *.dylib; do
	 ln -s "../lib/$lib" "/build/source/dep64/usr/lib64/$lib"; done)

	# /build/source/dep   - universal libraries
	# /build/source/dep32 - 32-bit libraries
	# /build/source/dep64 - lib64 symlinks for Wine compatibility

	# Create 32 bit portable tar
	mkdir /build/source/portable32
	cp -ar /build/source/tmp32/usr /build/source/portable32/
	cp -ar /build/source/dep32/usr /build/source/portable32/
	(cd /build/source/portable32 && fakeroot tar -cvzf "/build/output/portable-$package-$version-osx.tar.gz" .)
	rm -rf /build/source/portable32

	# Move duplicate files to a separate location
	mkdir /build/source/tmp
	move-duplicates.py --dir32 /build/source/tmp32 --dir64 /build/source/tmp64 --out /build/source/tmp

	# /build/source/tmp   - common 32-bit files
	# /build/source/tmp32 - 32-bit only files
	# /build/source/tmp64 - 64-bit only files

	# Create 64 bit portable tar
	mkdir /build/source/portable64
	cp -ar /build/source/tmp/usr   /build/source/portable64/
	cp -ar /build/source/tmp64/usr /build/source/portable64/
	cp -ar /build/source/dep/usr   /build/source/portable64/
	cp -ar /build/source/dep64/usr /build/source/portable64/
	(cd /build/source/portable64 && fakeroot tar -cvzf "/build/output/portable-$package-$version-osx64.tar.gz" .)
	rm -rf /build/source/portable64

	# Create payload directory for common 32 bit files
	cp -ar /build/source/osx-package/payload-wine /build/source/payload-tmp
	cp -ar /build/source/tmp/usr /build/source/payload-tmp/Contents/Resources/wine
	i686-apple-darwin12-clang -msse2 -framework Cocoa \
	               -o /build/source/payload-tmp/Contents/MacOS/wine \
	               /build/source/osx-package/wrapper.m

	# Create payload directory for 32 bit only files
	mkdir -p /build/source/payload-tmp32/Contents/Resources
	cp -ar /build/source/tmp32/usr /build/source/payload-tmp32/Contents/Resources/wine

	# Create payload directory for 64 bit only files
	mkdir -p /build/source/payload-tmp64/Contents/Resources
	cp -ar /build/source/tmp64/usr /build/source/payload-tmp64/Contents/Resources/wine

	# Create payload directory for universal libraries
	mkdir -p /build/source/payload-dep/Contents/Resources
	cp -ar /build/source/dep/usr /build/source/payload-dep/Contents/Resources/wine

	# Create payload directory for dep 64 symlink files
	mkdir -p /build/source/payload-dep64/Contents/Resources
	cp -ar /build/source/dep64/usr /build/source/payload-dep64/Contents/Resources/wine

	# Clean up remaining build files
	rm -rf /build/tmp{,32,64}
	rm -rf /build/dep{,32,64}

	# Assemble package
	mkdir /build/source/package
	osx-package.py -C /build/source/package init

	osx-package.py -C /build/source/package resources \
					--add /build/source/osx-package/resources

	osx-package.py -C /build/source/package settings \
					--title '{{ =pretty_name }}' \
					--welcome 'welcome.html' \
					--conclusion 'conclusion.html' \
					--background 'background.png' \
					--architecture i386 x86_64 \
					--allow-customization always \
					--allow-external-scripts false \
					--target-any-volume true \
					--target-user-home true \
					--target-local-system true \
					--script /build/source/osx-package/install-script \
					--installation-check 'pm_install_check();'

	# pkg - common 32 bit files
	osx-package.py -C /build/source/package pkg-add \
					--identifier org.winehq.{{ =package }} \
					--version {{ =package_version }} \
					--install-location '/Applications/{{ =pretty_name }}.app' \
					--payload /build/source/payload-tmp \
					--scripts /build/source/osx-package/scripts-wine \
					--preinstall-script preinstall.sh

	# pkg - 32 bit only files
	osx-package.py -C /build/source/package pkg-add \
					--identifier org.winehq.{{ =package }}32 \
					--version {{ =package_version }} \
					--install-location '/Applications/{{ =pretty_name }}.app' \
					--payload /build/source/payload-tmp32

	# pkg - 64 bit only files
	osx-package.py -C /build/source/package pkg-add \
					--identifier org.winehq.{{ =package }}64 \
					--version {{ =package_version }} \
					--install-location '/Applications/{{ =pretty_name }}.app' \
					--payload /build/source/payload-tmp64

	# pkg - universal dependencies (32 + 64 bit)
	osx-package.py -C /build/source/package pkg-add \
					--identifier org.winehq.{{ =package }}-deps \
					--version {{ =package_version }} \
					--install-location '/Applications/{{ =pretty_name }}.app' \
					--payload /build/source/payload-dep

	# pkg - symlinks for 64 bit dependencies
	osx-package.py -C /build/source/package pkg-add \
					--identifier org.winehq.{{ =package }}-deps64 \
					--version {{ =package_version }} \
					--install-location '/Applications/{{ =pretty_name }}.app' \
					--payload /build/source/payload-dep64

	# choice - dependencies (required)
	osx-package.py -C /build/source/package choice-add \
					--id choice0 \
					--title 'Dependencies' \
					--description 'Third party libraries which are required for Wine.' \
					--visible true \
					--enabled false \
					--selected true \
					--pkgs org.winehq.{{ =package }}-deps

	# choice - common 32 bit files (required)
	osx-package.py -C /build/source/package choice-add \
					--id choice1 \
					--title '32 bit support' \
					--description 'Support for running 32 bit applications in Wine.' \
					--visible true \
					--enabled false \
					--selected true \
					--pkgs org.winehq.{{ =package }}

	# choice - 32 bit only files (xor 64 bit support)
	osx-package.py -C /build/source/package choice-add \
					--id choice2 \
					--title '32 bit only files' \
					--description 'Files that are only required for non WOW 64 support.' \
					--visible false \
					--enabled false \
					--start-selected true \
					--selected "!choices['choice3'].selected" \
					--pkgs org.winehq.{{ =package }}32

	# choice - 64 bit files (64 bit WOW support)
	osx-package.py -C /build/source/package choice-add \
					--id choice3 \
					--title '64 bit support (optional)' \
					--description 'Support for running 64 bit applications in Wine.' \
					--visible true \
					--enabled true \
					--start-selected false \
					--pkgs org.winehq.{{ =package }}64 org.winehq.{{ =package }}-deps64

	osx-package.py -C /build/source/package generate \
					--output "/build/output/$package-$version.pkg"
}

export -f build_tools build_arch create_pkg
su builder -c "build_tools"
su builder -c "build_arch 32 i686-apple-darwin12 ''"
su builder -c "build_arch 64 x86_64-apple-darwin12 --enable-win64"
su builder -c "create_pkg ${depends[*]}"
