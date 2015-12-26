{{ __filename = __filename if package_boot else None }}
#!/bin/bash
set -e -x

apt-get update
apt-get upgrade -y
apt-get install -y git devscripts build-essential

{{
	debian_sources = [
		("llvm-toolchain-3.5_3.5-10.dsc",
		 "f3229ceeb39479fea20adcabf3e59bf8a850442f287e86302d581a34060f147a"),
		("llvm-toolchain-3.5_3.5.orig-clang-tools-extra.tar.bz2",
		 "ea549356548118ef82b727e1051a1b336bf2e8ea60c7932953749efccbd8be7f"),
		("llvm-toolchain-3.5_3.5.orig-clang.tar.bz2",
		 "afdd0af66908e7f91c9dc70e51f77fc97626b5fd59b94c3eba464ecdfd3e703a"),
		("llvm-toolchain-3.5_3.5.orig-compiler-rt.tar.bz2",
		 "d011491517640a87a4aa060ae9cb3a0de32bc8d3b0c373f7434904d6fad083dc"),
		("llvm-toolchain-3.5_3.5.orig-lldb.tar.bz2",
		 "8898513f1ecb05d07140d2377f1006d9ff3d04150025dba0355a0babfdcb5eb8"),
		("llvm-toolchain-3.5_3.5.orig-polly.tar.bz2",
		 "e1373b39c76a72f227058765159487dd53858afdf254bff7e881741ea908c1dd"),
		("llvm-toolchain-3.5_3.5.orig.tar.bz2",
		 "36649be6cecb54d0cd3d6148fffa42f7d43f53e3f8e0303f35a75ad15d83aec3"),
		("llvm-toolchain-3.5_3.5-10.debian.tar.xz",
		 "93af761eaeedb6af56f2d21a2e22aa4eb801ca044c86ca7fd01a4d73aacda51e"),
	]

	for name, sha in debian_sources
		download(name, "http://http.debian.net/debian/pool/main/l/llvm-toolchain-3.5/%s" % name, sha)
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
