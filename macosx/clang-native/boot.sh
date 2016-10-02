{{ __filename = __filename if package_boot else None }}
#!/bin/bash
set -e -x

apt-get update
apt-get upgrade -y
apt-get install -y git devscripts build-essential

{{
	debian_sources = [
		("llvm-toolchain-3.8_3.8-2.dsc",
		 None), # "4444047c26b50222361af61a11b6eebc05a0744c93fa75af3b0ca1d90204d30f"
		("llvm-toolchain-3.8_3.8.orig-clang-tools-extra.tar.bz2",
		 None), # "829294015ce07d3f115f5dda2422c9c4efbcb0f3d704df9673b0f3ad238ae390"
		("llvm-toolchain-3.8_3.8.orig-clang.tar.bz2",
		 None), # "c9a786040bbda4f2aa7d26474567bf4d9c9b9a0fa5b0f5fea51c6f4f37fe62d1"
		("llvm-toolchain-3.8_3.8.orig-compiler-rt.tar.bz2",
		 None), # "93e34592b651377ed86d6085e1b71cfad8c4023ded934d5f03ca700eb56a888e"
		("llvm-toolchain-3.8_3.8.orig-lldb.tar.bz2",
		 None), # "9664e4f349d22de29fd4eb6945c93995c72a4a19aaa176c31ba592c7d4fcf349"
		("llvm-toolchain-3.8_3.8.orig-polly.tar.bz2",
		 None), # "c0f408b252685dfb15a7e0818305efacbf56190f128f5f08fea36284f7e4327a"
		("llvm-toolchain-3.8_3.8.orig.tar.bz2",
		 None), # "e9f28eef0e452efcf03fea2f24e336c126bd63578c9db21bf1544f326bbd8405"
		("llvm-toolchain-3.8_3.8-2.debian.tar.xz",
		 None), # "8866c9f1a82e475e881bb9992d901287b94d510f1ed67a35a8118cf03b039388"
	]

	for name, sha in debian_sources
		download(name, "http://http.debian.net/debian/pool/main/l/llvm-toolchain-3.8/%s" % name, sha)
	endfor
}}

cd ..
su builder -c "dpkg-source -x source/llvm-toolchain-3.8_3.8-2.dsc"
cd llvm-toolchain-3.8-3.8

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
