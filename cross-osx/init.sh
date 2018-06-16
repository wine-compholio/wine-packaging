#!/bin/bash

set -ex

# Add the debian repository with the dependencies
apt-key add /build/deps/Release.key
echo "deb file:///build/deps/debian stretch main" > /etc/apt/sources.list.d/osx-deps.list
apt-get update

# Pin our own packages (especially clang)
(
	echo 'Package: *'
	echo 'Pin: origin ""'
	echo 'Pin-Priority: 1000'
) > /etc/apt/preferences.d/osx-deps

# Install native tools
apt-get install -y clang clang-3.8 cctools-i686-darwin12 cctools-x86-64-darwin12 bomutils xar

# Extract MacOS rootfs
mkdir /build/macos-rootfs
tar --no-same-owner -C /build/macos-rootfs -xf /build/deps/macosx/MacOSX10.8.sdk.tar.xz --strip-components 1

# Create an empty filelist
echo -n "" > /build/deps/filelist.txt

# Create wrapper for clang
(
  echo "#!/bin/bash"
  echo "clang -target i686-apple-darwin12 -mlinker-version=0.0 -isysroot \"/build/macos-rootfs\" \"\$@\""
) > /usr/bin/i686-apple-darwin12-clang
chmod +x /usr/bin/i686-apple-darwin12-clang

ln -s /usr/bin/i686-apple-darwin12-clang /usr/bin/i686-apple-darwin12-gcc

# Create wrapper for clang (64 bit)
(
  echo "#!/bin/bash"
  echo "clang -target x86_64-apple-darwin12 -mlinker-version=0.0 -isysroot \"/build/macos-rootfs\" \"\$@\""
) > /usr/bin/x86_64-apple-darwin12-clang
chmod +x /usr/bin/x86_64-apple-darwin12-clang

ln -s /usr/bin/x86_64-apple-darwin12-clang /usr/bin/x86_64-apple-darwin12-gcc

# Create wrapper for clang++
(
  echo "#!/bin/bash"
  echo "clang++ -target i686-apple-darwin12 -mlinker-version=0.0 -isysroot \"/build/macos-rootfs\" \"\$@\""
) > /usr/bin/i686-apple-darwin12-clang++
chmod +x /usr/bin/i686-apple-darwin12-clang++

ln -s /usr/bin/i686-apple-darwin12-clang++ /usr/bin/i686-apple-darwin12-g++
ln -s /usr/bin/i686-apple-darwin12-clang++ /usr/bin/i686-apple-darwin12-cpp

# Create wrapper for clang++ (64 bit)
(
  echo "#!/bin/bash"
  echo "clang++ -target x86_64-apple-darwin12 -mlinker-version=0.0 -isysroot \"/build/macos-rootfs\" \"\$@\""
) > /usr/bin/x86_64-apple-darwin12-clang++
chmod +x /usr/bin/x86_64-apple-darwin12-clang++

ln -s /usr/bin/x86_64-apple-darwin12-clang++ /usr/bin/x86_64-apple-darwin12-g++
ln -s /usr/bin/x86_64-apple-darwin12-clang++ /usr/bin/x86_64-apple-darwin12-cpp

# Create wrapper for pkg-config
(
  echo "#!/bin/bash"
  echo "export PKG_CONFIG_DIR="
  echo "export PKG_CONFIG_SYSROOT_DIR=/build/macos-rootfs"
  echo "export PKG_CONFIG_LIBDIR=/build/macos-rootfs/usr/lib/pkgconfig:/build/macos-rootfs/opt/X11/lib/pkgconfig"
  echo "pkg-config \"\$@\""
) > /usr/bin/i686-apple-darwin12-pkg-config
chmod +x /usr/bin/i686-apple-darwin12-pkg-config

ln -s /usr/bin/i686-apple-darwin12-pkg-config /usr/bin/x86_64-apple-darwin12-pkg-config

# Create stub for dsymutil
(
  echo "#!/bin/bash"
  echo "echo \"dsymutil stub: \$@\" >&2"
) > /usr/bin/i686-apple-darwin12-dsymutil
chmod +x /usr/bin/i686-apple-darwin12-dsymutil

ln -s /usr/bin/i686-apple-darwin12-dsymutil /usr/bin/x86_64-apple-darwin12-dsymutil

# Symlink some useful scripts
ln -s /build/deps/bin/fixup-import.py /usr/local/bin/fixup-import.py
ln -s /build/deps/bin/make-universal.py /usr/local/bin/make-universal.py
ln -s /build/deps/bin/install-dep.py /usr/local/bin/install-dep.py
ln -s /build/deps/bin/osx-package.py /usr/local/bin/osx-package.py
ln -s /build/deps/bin/move-duplicates.py /usr/local/bin/move-duplicates.py

# Prevent second execution of script
chmod -x /build/deps/bin/init.sh

# Run original build script
exec /build/source/build.sh
