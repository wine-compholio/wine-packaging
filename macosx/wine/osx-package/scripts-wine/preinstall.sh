#!/bin/bash
install_dir="$2"

# Do some security checks and remove previous wine versions
if [ ! -d "$install_dir/Contents/Resources/wine" ]; then exit 0; fi
if [ ! -f "$install_dir/Contents/Resources/wine/bin/wine" ]; then exit 0; fi
if [ ! -f "$install_dir/Contents/Resources/wine/lib/libwine.1.dylib" ]; then exit 0; fi

rm -rf "$install_dir/Contents/Resources/wine"
exit 0
