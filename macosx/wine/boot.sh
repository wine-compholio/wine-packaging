{{ __filename = __filename if package_boot else None }}
{{
	output = "%s-%s" % (compat_package, package_version)
	output += "-%s" % package_release if package_release != "" else ""
}}
#!/bin/bash
set -e -x

apt-get update
apt-get upgrade -y
apt-get install -y git devscripts build-essential python-magic python-lxml

{{ =include("../macosx-common.sh") }}
tar --skip-old-files -C /build/macos-rootfs -xf /build/source/deps/xquartz-*.tar.xz
(
	tar -C /build/macos-rootfs -xvf /build/source/deps/libjpeg-turbo-*-osx64.tar.gz
	tar -C /build/macos-rootfs -xvf /build/source/deps/liblcms2-*-osx64.tar.gz
	tar -C /build/macos-rootfs -xvf /build/source/deps/liblzma-*-osx64.tar.gz
	tar -C /build/macos-rootfs -xvf /build/source/deps/libopenal-soft-*-osx64.tar.gz
	tar -C /build/macos-rootfs -xvf /build/source/deps/libtiff-*-osx64.tar.gz
	tar -C /build/macos-rootfs -xvf /build/source/deps/libxml2-*-osx64.tar.gz
	tar -C /build/macos-rootfs -xvf /build/source/deps/libxslt-*-osx64.tar.gz
{{ if staging }}
	tar -C /build/macos-rootfs -xvf /build/source/deps/libtxc-dxtn-s2tc-*-osx64.tar.gz
{{ endif }}
) > /build/source/deps/filelist.txt

{{
	# FIXME: Fix support for daily builds - snapshot urls are no longer available
	url = "https://dl.winehq.org/wine/source"
	version = "%s/wine-%s" % (".".join(package_version.split("-")[0].split(".")[:2]), package_version)
	download("wine.tar.bz2", "%s/%s.tar.bz2" % (url, version), wine_sha)
}}
su builder -c "tar -xf wine.tar.bz2 --strip-components 1"
rm wine.tar.bz2

{{ if staging }}
{{
	url = "https://github.com/wine-compholio/wine-staging/archive"
	version = "master" if package_daily else "v%s" % package_version
	download("wine-staging.tar.gz", "%s/%s.tar.gz" % (url, version), staging_sha)
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
su builder -c "../source/configure --enable-win64"
cp /build/wine-tools/config.log /build/config-tools.log
su builder -c "make __tooldeps__ -j3"

# Build for OSX
{{ for (host, arch, extra_flags) in [("i686-apple-darwin12", "", ""), ("x86_64-apple-darwin12", "64", "--enable-win64")] }}

su builder -c "mkdir /build/wine-cross{{ =arch }}"
cd /build/wine-cross{{ =arch }}
su builder -c "../source/configure --prefix=/usr --host {{ =host }} --with-wine-tools=../wine-tools \
				--x-includes=/build/macos-rootfs/opt/X11/include --x-libraries=/build/macos-rootfs/opt/X11/lib \
				{{ =extra_flags }} LDFLAGS='-Wl,-rpath,/opt/x11/lib' CFLAGS='-msse2'"
cp config.log /build/config-cross{{ =arch }}.log
su builder -c "make -j3"
su builder -c "mkdir /build/tmp{{ =arch }}"
su builder -c "make install DESTDIR=/build/tmp{{ =arch }}/"
su builder -c "mkdir -p /build/tmp{{ =arch }}/usr/share/doc/wine"
su builder -c "cp -a /build/source/{ANNOUNCE,LICENSE,COPYING.*} /build/tmp{{ =arch }}/usr/share/doc/wine"
su builder -c "/build/source/fixup-import.py --destdir /build/tmp{{ =arch }} --filelist /build/source/deps/filelist.txt --verbose"
su builder -c "/build/source/fixup-import.py --destdir /build/tmp{{ =arch }} --install_name --verbose"
su builder -c "(cd /build/tmp{{ =arch }}; fakeroot tar -cvzf /build/{{ =output }}-osx{{ =arch }}.tar.gz .)"

cd ..

{{ endfor }}

# Unpack dependencies
{{ for (dir, arch) in [("32", ""), ("", "64")] }}

su builder -c "mkdir /build/tmp-deps{{ =dir }}"
su builder -c "tar -C /build/tmp-deps{{ =dir }} -xf /build/source/deps/libjpeg-turbo-*-osx{{ =arch }}.tar.gz"
su builder -c "tar -C /build/tmp-deps{{ =dir }} -xf /build/source/deps/liblcms2-*-osx{{ =arch }}.tar.gz"
su builder -c "tar -C /build/tmp-deps{{ =dir }} -xf /build/source/deps/liblzma-*-osx{{ =arch }}.tar.gz"
su builder -c "tar -C /build/tmp-deps{{ =dir }} -xf /build/source/deps/libopenal-soft-*-osx{{ =arch }}.tar.gz"
su builder -c "tar -C /build/tmp-deps{{ =dir }} -xf /build/source/deps/libtiff-*-osx{{ =arch }}.tar.gz"
su builder -c "tar -C /build/tmp-deps{{ =dir }} -xf /build/source/deps/libxml2-*-osx{{ =arch }}.tar.gz"
su builder -c "tar -C /build/tmp-deps{{ =dir }} -xf /build/source/deps/libxslt-*-osx{{ =arch }}.tar.gz"
{{ if staging }}
su builder -c "tar -C /build/tmp-deps{{ =dir }} -xf /build/source/deps/libtxc-dxtn-s2tc-*-osx{{ =arch }}.tar.gz"
{{ endif }}
su builder -c "/build/source/fixup-import.py --destdir /build/tmp-deps{{ =dir }} --install_name --verbose"

{{ endfor }}

# We need to create symlinks from lib64 -> lib
# Our dependencies are universal binaries but
# Wine64 only searches in PREFIX/lib64.
su builder -c "mkdir -p /build/tmp-deps64/usr/lib64"
su builder -c "(cd /build/tmp-deps/usr/lib; for lib in *.dylib; \
               do ln -s \"../lib/\$lib\" \"/build/tmp-deps64/usr/lib64/\$lib\"; done)"

# /build/tmp-deps 	- universal libraries
# /build/tmp-deps32 - 32-bit libraries
# /build/tmp-deps64 - lib64 symlinks for Wine compatibility

# Create 32 bit portable tar
su builder -c "mkdir /build/tmp-portable32"
su builder -c "cp -ar /build/tmp/usr /build/tmp-portable32/"
su builder -c "cp -ar /build/tmp-deps32/usr /build/tmp-portable32/"
su builder -c "(cd /build/tmp-portable32/; fakeroot tar -cvzf /build/portable-{{ =output }}-osx.tar.gz .)"
rm -rf /build/tmp-portable32

# Move duplicate files to a separate location
su builder -c "mkdir /build/tmp32"
su builder -c "/build/source/move-duplicates.py --dir32 /build/tmp --dir64 /build/tmp64 --out /build/tmp32"

# /build/tmp 	- common 32-bit files
# /build/tmp64 	- 64-bit only files
# /build/tmp32  - 32-bit only files

# Create 64 bit portable tar
su builder -c "mkdir /build/tmp-portable64"
su builder -c "cp -ar /build/tmp/usr /build/tmp-portable64/"
su builder -c "cp -ar /build/tmp64/usr /build/tmp-portable64/"
su builder -c "cp -ar /build/tmp-deps/usr /build/tmp-portable64/"
su builder -c "cp -ar /build/tmp-deps64/usr /build/tmp-portable64/"
su builder -c "(cd /build/tmp-portable64/; fakeroot tar -cvzf /build/portable-{{ =output }}-osx64.tar.gz .)"
rm -rf /build/tmp-portable64

# Create payload directory for common 32 bit files
su builder -c "cp -ar /build/source/osx-package/payload-wine /build/tmp-osx-payload"
su builder -c "cp -ar /build/tmp/usr /build/tmp-osx-payload/Contents/Resources/wine"
su builder -c "i686-apple-darwin12-clang -msse2 -framework Cocoa \
               -o /build/tmp-osx-payload/Contents/MacOS/wine \
               /build/source/osx-package/wrapper.m"

# Create payload directory for 32 bit only files
su builder -c "mkdir -p /build/tmp-osx-payload32/Contents/Resources"
su builder -c "cp -ar /build/tmp32/usr /build/tmp-osx-payload32/Contents/Resources/wine"

# Create payload directory for 64 bit only files
su builder -c "mkdir -p /build/tmp-osx-payload64/Contents/Resources"
su builder -c "cp -ar /build/tmp64/usr /build/tmp-osx-payload64/Contents/Resources/wine"

# Create payload directory for dep files
su builder -c "mkdir -p /build/tmp-osx-payload-deps/Contents/Resources"
su builder -c "cp -ar /build/tmp-deps/usr /build/tmp-osx-payload-deps/Contents/Resources/wine"

# Create payload directory for dep 64 symlink files
su builder -c "mkdir -p /build/tmp-osx-payload-deps64/Contents/Resources"
su builder -c "cp -ar /build/tmp-deps64/usr /build/tmp-osx-payload-deps64/Contents/Resources/wine"

# Clean up remaining build files
rm -rf /build/tmp
rm -rf /build/tmp32
rm -rf /build/tmp64
rm -rf /build/tmp-deps
rm -rf /build/tmp-deps32
rm -rf /build/tmp-deps64

# Assemble package
cd /build/source/osx-package
su builder -c "mkdir /build/tmp-osx-pkg"
su builder -c "./osx-package.py -C /build/tmp-osx-pkg init"

su builder -c "./osx-package.py -C /build/tmp-osx-pkg resources \
				--add /build/source/osx-package/resources"

su builder -c "./osx-package.py -C /build/tmp-osx-pkg settings \
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
				--installation-check 'pm_install_check();'"

# pkg - common 32 bit files
su builder -c "./osx-package.py -C /build/tmp-osx-pkg pkg-add \
				--identifier org.winehq.{{ =package }} \
				--version {{ =package_version }} \
				--install-location '/Applications/{{ =pretty_name }}.app' \
				--payload /build/tmp-osx-payload \
				--scripts /build/source/osx-package/scripts-wine \
				--preinstall-script preinstall.sh"

# pkg - 32 bit only files
su builder -c "./osx-package.py -C /build/tmp-osx-pkg pkg-add \
				--identifier org.winehq.{{ =package }}32 \
				--version {{ =package_version }} \
				--install-location '/Applications/{{ =pretty_name }}.app' \
				--payload /build/tmp-osx-payload32"

# pkg - 64 bit only files
su builder -c "./osx-package.py -C /build/tmp-osx-pkg pkg-add \
				--identifier org.winehq.{{ =package }}64 \
				--version {{ =package_version }} \
				--install-location '/Applications/{{ =pretty_name }}.app' \
				--payload /build/tmp-osx-payload64"

# pkg - universal dependencies (32 + 64 bit)
su builder -c "./osx-package.py -C /build/tmp-osx-pkg pkg-add \
				--identifier org.winehq.{{ =package }}-deps \
				--version {{ =package_version }} \
				--install-location '/Applications/{{ =pretty_name }}.app' \
				--payload /build/tmp-osx-payload-deps"

# pkg - symlinks for 64 bit dependencies
su builder -c "./osx-package.py -C /build/tmp-osx-pkg pkg-add \
				--identifier org.winehq.{{ =package }}-deps64 \
				--version {{ =package_version }} \
				--install-location '/Applications/{{ =pretty_name }}.app' \
				--payload /build/tmp-osx-payload-deps64"

# choice - dependencies (required)
su builder -c "./osx-package.py -C /build/tmp-osx-pkg choice-add \
				--id choice0 \
				--title 'Dependencies' \
				--description 'Third party libraries which are required for Wine.' \
				--visible true \
				--enabled false \
				--selected true \
				--pkgs org.winehq.{{ =package }}-deps"

# choice - common 32 bit files (required)
su builder -c "./osx-package.py -C /build/tmp-osx-pkg choice-add \
				--id choice1 \
				--title '32 bit support' \
				--description 'Support for running 32 bit applications in Wine.' \
				--visible true \
				--enabled false \
				--selected true \
				--pkgs org.winehq.{{ =package }}"

# choice - 32 bit only files (xor 64 bit support)
su builder -c "./osx-package.py -C /build/tmp-osx-pkg choice-add \
				--id choice2 \
				--title '32 bit only files' \
				--description 'Files that are only required for non WOW 64 support.' \
				--visible false \
				--enabled false \
				--start-selected true \
				--selected \"!choices['choice3'].selected\" \
				--pkgs org.winehq.{{ =package }}32"

# choice - 64 bit files (64 bit WOW support)
su builder -c "./osx-package.py -C /build/tmp-osx-pkg choice-add \
				--id choice3 \
				--title '64 bit support (experimental)' \
				--description 'Support for running 64 bit applications in Wine.' \
				--visible true \
				--enabled true \
				--start-selected false \
				--pkgs org.winehq.{{ =package }}64 org.winehq.{{ =package }}-deps64"

su builder -c "./osx-package.py -C /build/tmp-osx-pkg generate \
				--output /build/{{ =output }}.pkg"
