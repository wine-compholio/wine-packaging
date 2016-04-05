{{ __filename = __filename if package_boot else None }}
#!/bin/bash
set -e -x

apt-get update
apt-get upgrade -y
apt-get install -y git devscripts build-essential

{{
	debian_sources = [
		("llvm-defaults_0.33.dsc",
		 "8921399a08e68b44275ab356375d6ca079315ecfc578081ef10705295441dac8"),
		("llvm-defaults_0.33.tar.xz",
		 "171206277066aad042d72136b33a9382e20da031c47f958d8951f0a9ffcbf1c7"),
	]

	for name, sha in debian_sources
		download(name, "http://http.debian.net/debian/pool/main/l/llvm-defaults/%s" % name, sha)
	endfor
}}

cd ..
su builder -c "dpkg-source -x source/llvm-defaults_0.33.dsc"
cd llvm-defaults-0.33

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
