#!/usr/bin/python2
# -*- coding: utf-8 -*-
#
# Tool to combine 32-bit and 64-bit Macho files.
#
# Copyright (C) 2016 Michael Müller
# Copyright (C) 2016 Sebastian Lackner
#
# This library is free software; you can redistribute it and/or
# modify it under the terms of the GNU Lesser General Public
# License as published by the Free Software Foundation; either
# version 2.1 of the License, or (at your option) any later version.
#
# This library is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# Lesser General Public License for more details.
#
# You should have received a copy of the GNU Lesser General Public
# License along with this library; if not, write to the Free Software
# Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA 02110-1301, USA
#

import argparse
import os
import stat
import subprocess
import shutil

# Check if a file is a mach executable
def is_mach_executable(path):
    with open(path, "rb") as f:
        buf = f.read(16)

    if buf[0:4] != "\xCE\xFA\xED\xFE" and buf[0:4] != "\xCF\xFA\xED\xFE": return False
    if buf[4:8] != "\x07\x00\x00\x00" and buf[4:8] != "\x07\x00\x00\x01": return False
    return (buf[12:16] == "\x02\x00\x00\x00")

# Check if a file is a mach dylib
def is_mach_dylib(path):
    with open(path, "rb") as f:
        buf = f.read(16)

    if buf[0:4] != "\xCE\xFA\xED\xFE" and buf[0:4] != "\xCF\xFA\xED\xFE": return False
    if buf[4:8] != "\x07\x00\x00\x00" and buf[4:8] != "\x07\x00\x00\x01": return False
    return (buf[12:16] == "\x06\x00\x00\x00" or buf[12:16] == "\x08\x00\x00\x00")

def is_ar_archive(path):
    with open(path, "rb") as f:
        buf = f.read(8)

    return (buf == "!<arch>\n")

# Combine two macho files into a universal binary
def combine_macho(file32, file64):

    if file32.endswith(".dylib") or file32.endswith(".so"):
        assert is_mach_dylib(file32)
    elif file32.endswith(".a"):
        assert is_ar_archive(file32)
    else:
        mode = os.stat(file32).st_mode
        if not (stat.S_IXUSR & mode): return
        if not is_mach_executable(file32): return

    print "Combining %s and %s" % (file32, file64)

    tmp_file = "%s.universal" % file64
    subprocess.check_call(["x86_64-apple-darwin12-lipo", "-create",
                           "-arch", "i386", file32, "-arch", "x86_64", file64,
                           "-output", tmp_file])

    shutil.copystat(file64, tmp_file)
    os.rename(tmp_file, file64)

# Recursively go through all files in DESTDIR, and combine files
def combine_files(dir32, dir64):
    for filename in os.listdir(dir32):
        full_path = os.path.join(dir32, filename)

        if os.path.islink(full_path):
            file64 = os.path.join(dir64, filename)
            assert os.path.islink(file64)

        elif os.path.isfile(full_path):
            file64 = os.path.join(dir64, filename)
            assert os.path.isfile(file64)
            combine_macho(full_path, file64)

        elif os.path.isdir(full_path):
            combine_files(full_path, os.path.join(dir64, filename))

def main():
    parser = argparse.ArgumentParser(description="Tool to create universal Macho files")
    parser.add_argument('--dir32', help="Directory to the 32 bit executables", required=True)
    parser.add_argument('--dir64', help="Directory to the 64 bit executables (output dir)", required=True)
    args = parser.parse_args()

    combine_files(args.dir32, args.dir64)

if __name__ == '__main__':
    main()
