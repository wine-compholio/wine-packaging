#!/bin/bash
set -e -x

if [ "$(uname -m)" == "x86_64" ]; then
	sed -i "s/^%_lib .*$/%_lib lib64/g" rpmmacros
fi

mkdir -p /home/build/wine/{BUILD,BUILDROOT,RPMS,SPECS,SRPMS,tmp}
ln -s "$(pwd)/rpmmacros" /home/build/.rpmmacros
ln -s "$(pwd)/../output" /home/build/wine/RPMS/i586
ln -s "$(pwd)/../output" /home/build/wine/RPMS/x86_64
ln -s "$(pwd)/../output" /home/build/wine/RPMS/noarch
ln -s "$(pwd)" 			 /home/build/wine/SOURCES
for _f in *.spec; do
	ln -s "$(pwd)/$_f"  "/home/build/wine/SPECS/$_f"
done
chown -R build:build /home/build/wine

for _f in *.spec; do
	dnf builddep -y "$_f"
	su build -c "cd /home/build/wine/SPECS && BUILDER_TOPDIR=/home/build/wine rpmbuild -vv -bb \"$_f\""
done

for _f in ../output/*.rpm; do
	if rpm -qpR "$_f" | grep "wine-missing-buildrequires-"; then
		echo "Missing build requirements, package would be broken!" >&2
		exit 1
	fi
done
