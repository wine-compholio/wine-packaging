{{ __filename = __filename if package_boot else None }}
#!/bin/bash
set -e -x

apt-get update
apt-get upgrade -y
apt-get install -y git devscripts build-essential

{{
	debian_sources = [
			"llvm-toolchain-3.5_3.5-10.dsc",
			"llvm-toolchain-3.5_3.5.orig-clang-tools-extra.tar.bz2",
			"llvm-toolchain-3.5_3.5.orig-clang.tar.bz2",
			"llvm-toolchain-3.5_3.5.orig-compiler-rt.tar.bz2",
			"llvm-toolchain-3.5_3.5.orig-lldb.tar.bz2",
			"llvm-toolchain-3.5_3.5.orig-polly.tar.bz2",
			"llvm-toolchain-3.5_3.5.orig.tar.bz2",
			"llvm-toolchain-3.5_3.5-10.debian.tar.xz"
		]

	for source in debian_sources
		download(source, "http://http.debian.net/debian/pool/main/l/llvm-toolchain-3.5/%s" % source)
	endfor
}}

cd ..
su builder -c "dpkg-source -x source/llvm-toolchain-3.5_3.5-10.dsc"
cd llvm-toolchain-3.5-3.5

if ls ../source/*.patch &> /dev/null; then
	cat ../source/*.patch | patch -p1
fi

mv debian/changelog debian/changelog.old
(
  grep -m1 "(" debian/changelog.old | sed -e "s/)/~{{ =debian_codename }})/"
  echo "  * Auto build."
  grep -m1 " -- " debian/changelog.old | sed -e "s/  .*/  {{ =debian_time }}/"
  echo ""
  echo ""
  cat debian/changelog.old
) > debian/changelog
rm debian/changelog.old

mk-build-deps -i -r -t "apt-get -y" debian/control
su builder -c "DEB_BUILD_OPTIONS=nocheck debuild -us -uc -b -j3"
