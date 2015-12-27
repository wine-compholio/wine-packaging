{{ =include("clang-common.sh") }}

dpkg -i /build/source/deps/cctools-i686-darwin12_877.5-1~jessie_i386.deb \
        /build/source/deps/bomutils_0.2-1~jessie_i386.deb \
        /build/source/deps/xar_1.6.1-1~jessie_i386.deb

mkdir /build/macos-rootfs
cd /build/macos-rootfs
tar -xf ../source/deps/MacOSX10.8.sdk.tar.xz --strip-components 1

# Create compiler wrapper / symlinks
(
  echo "#!/bin/bash"
  echo "clang -target i686-apple-darwin12 -mlinker-version=0.0 -isysroot \"/build/macos-rootfs\" \"\$@\""
) > /usr/bin/i686-apple-darwin12-clang
chmod +x /usr/bin/i686-apple-darwin12-clang

ln -s /usr/bin/i686-apple-darwin12-clang /usr/bin/i686-apple-darwin12-gcc

(
  echo "#!/bin/bash"
  echo "clang++ -target i686-apple-darwin12 -mlinker-version=0.0 -isysroot \"/build/macos-rootfs\" \"\$@\""
) > /usr/bin/i686-apple-darwin12-clang++
chmod +x /usr/bin/i686-apple-darwin12-clang++

ln -s /usr/bin/i686-apple-darwin12-clang++ /usr/bin/i686-apple-darwin12-g++
ln -s /usr/bin/i686-apple-darwin12-clang++ /usr/bin/i686-apple-darwin12-cpp

# Create wrapper for pkg config
(
  echo "#!/bin/bash"
  echo "export PKG_CONFIG_DIR="
  echo "export PKG_CONFIG_SYSROOT_DIR=/build/macos-rootfs"
  echo "export PKG_CONFIG_LIBDIR=/build/macos-rootfs/usr/lib/pkgconfig:/build/macos-rootfs/opt/X11/lib/pkgconfig"
  echo "pkg-config \"\$@\""
) > /usr/bin/i686-apple-darwin12-pkg-config
chmod +x /usr/bin/i686-apple-darwin12-pkg-config

chown root:builder /build/macos-rootfs
chmod 0775 /build/macos-rootfs

cd /build/source
