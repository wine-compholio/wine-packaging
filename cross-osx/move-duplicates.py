#!/usr/bin/python2
# -*- coding: utf-8 -*-
#
# Tool to move duplicate files
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
import errno
import os
import stat
import subprocess
import shutil

def try_mkdir_p(path):
    try:
        os.makedirs(path)
    except OSError as exc:
        if exc.errno == errno.EEXIST:
            return False
        else:
            raise
    return True

# Recursively go through all files in DESTDIR, and combine files
def move_files(dir32, dir64, dirout):
    for filename in os.listdir(dir32):
        full_path = os.path.join(dir32, filename)

        if os.path.islink(full_path):
            file64 = os.path.join(dir64, filename)
            if not os.path.exists(file64):
                try_mkdir_p(dirout)
                shutil.move(full_path, dirout)

        elif os.path.isfile(full_path):
            file64 = os.path.join(dir64, filename)
            if not os.path.exists(file64):
                try_mkdir_p(dirout)
                shutil.move(full_path, dirout)

        elif os.path.isdir(full_path):
            move_files(full_path, os.path.join(dir64, filename), os.path.join(dirout, filename))

def main():
    parser = argparse.ArgumentParser(description="Move common files to a separate directory")
    parser.add_argument('--dir32', help="Directory to the 32 bit executables", required=True)
    parser.add_argument('--dir64', help="Directory to the 64 bit executables", required=True)
    parser.add_argument('--out', help="Output directory for common files", required=True)
    args = parser.parse_args()

    # After the script is finished, the directories will contain:
    # dir32: 32-bit specific files
    # dir64: 64-bit specific files
    # out:   files commonly used by 32-bit and 64-bit

    move_files(args.dir32, args.dir64, args.out)

if __name__ == '__main__':
    main()
