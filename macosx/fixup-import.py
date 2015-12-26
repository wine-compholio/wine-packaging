#!/usr/bin/python2
# -*- coding: utf-8 -*-
#
# Tool to fixup imports in Macho files.
#
# Copyright (C) 2015 Michael Müller
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

# Load list of files into a set
def load_filelist(path):
    files = set()

    if path is None:
        return files

    with open(path, "r") as f:
        for line in f:
            line = line.strip()
            if line.startswith("./"):
                line = line[1:]
            assert line[0] == "/"
            files.add(line)

    return files

# Get imports for a Macho file
def get_imports(path):
    lines = subprocess.check_output(["i686-apple-darwin12-otool", "-L", path])

    imports = []
    for line in lines.split('\n')[1:]:

        if line == "":
            continue

        import_file = line.split("(", 1)[0].strip()
        imports.append(import_file)

    return imports

# Fixup imports of destdir:path
def fix_imports(destdir, path, dependency_list, verbose):
    full_path = os.path.join(destdir, path)

    if verbose:
        print "Fixing imports for %s:" % path

    imports = get_imports(full_path)
    for import_path in imports:

        if import_path == "/" + path:
            continue

        if import_path.startswith("@rpath"):
            continue

        if import_path.startswith("@loader_path"):
            print "Warning: Import path (%s) starts with loader_path." % import_path
            continue

        assert import_path[0] == '/'

        # check if the new package depends on its own files, or
        # if the file is provided by one of the dependencies
        test_path = os.path.join(destdir, import_path[1:])
        needs_fixup = os.path.isfile(test_path) or \
                      import_path in dependency_list

        if needs_fixup:
            new_import_path = "@loader_path/" + os.path.relpath(import_path, "/%s" % os.path.dirname(path))

            if verbose:
                print "%s -> %s" % (import_path, new_import_path)

            subprocess.check_call(["i686-apple-darwin12-install_name_tool", "-change",
                                  import_path, new_import_path, full_path])

    if verbose:
        print ""

# Check if a file is a macho file
def is_macho_file(path):
    # check for .dylib path
    if path.endswith(".dylib"):
        return True

    # check if executable
    mode = os.stat(path).st_mode
    if not stat.S_IXUSR & mode:
        return False

    # check for macho magic
    with open(path, "rb") as f:
        buf = f.read(8)
        if buf[0:4] != "\xCE\xFA\xED\xFE" and buf[0:4] != "\xCF\xFA\xED\xFE":
            return False
        if buf[4:8] != "\x07\x00\x00\x00" and buf[4:8] != "\x07\x00\x00\x01":
            return False

    return True

# Recursively go through all files in DESTDIR, and update import paths
def check_files(destdir, path, dependency_list, verbose):
    for filename in os.listdir(os.path.join(destdir, path)):
        full_path = os.path.join(destdir, path, filename)

        if os.path.islink(full_path):
            continue

        elif os.path.isfile(full_path):
            if not is_macho_file(full_path):
                continue

            fix_imports(destdir, os.path.join(path, filename), dependency_list, verbose)

        elif os.path.isdir(full_path):
            check_files(destdir, os.path.join(path, filename), dependency_list, verbose)

if __name__ == '__main__':
    parser = argparse.ArgumentParser(description="Tool to fixup imports in Macho files")
    parser.add_argument('--filelist', help="List of relative files", default=None)
    parser.add_argument('--destdir', help="Directory which should be fixed", required=True)
    parser.add_argument('--verbose', action='store_true', help="Print changes")
    args = parser.parse_args()

    dependency_list = load_filelist(args.filelist)
    check_files(args.destdir, "", dependency_list, args.verbose)
