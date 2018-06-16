#!/bin/bash
set -e -x

if [ "$(uname -m)" == "x86_64" ]; then
	sed -i "s/^%_lib .*$/%_lib lib64/g" rpmmacros
fi

mkdir -p /home/builder/wine/{BUILD,BUILDROOT,RPMS,SPECS,SRPMS,tmp}
ln -s "$(pwd)/rpmmacros" /home/builder/.rpmmacros
ln -s "$(pwd)/../output" /home/builder/wine/RPMS/i686
ln -s "$(pwd)/../output" /home/builder/wine/RPMS/x86_64
ln -s "$(pwd)/../output" /home/builder/wine/RPMS/noarch
ln -s "$(pwd)" 			 /home/builder/wine/SOURCES
for _f in *.spec; do
	ln -s "$(pwd)/$_f"  "/home/builder/wine/SPECS/$_f"
done
chown -R builder:builder /home/builder/wine

for _f in *.spec; do
	dnf builddep -y "$_f"
	su builder -c "cd /home/builder/wine/SPECS && BUILDER_TOPDIR=/home/builder/wine rpmbuild -vv -bb \"$_f\""
done

for _f in ../output/*.rpm; do
	if rpm -qpR "$_f" | grep "wine-missing-buildrequires-"; then
		echo "Missing build requirements, package would be broken!" >&2
		exit 1
	fi
done
