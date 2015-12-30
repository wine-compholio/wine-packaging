#!/bin/bash
#
# Clean dependencies directory
#
# Copyright (C) 2015 Sebastian Lackner
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

/usr/bin/python2 - <<END
import os, re, sys

DEPENDENCIES = "/nfs/share/macosx-builds/deps"

def parse_subversion(v):
    for i, c in enumerate(re.split("([0-9]+)", v)):
        if i % 2 == 0: yield c
        else: yield int(c)

def parse_version(v):
    for i, c in enumerate(re.split("([-.~])", v)):
        if i % 2 == 0: yield tuple(parse_subversion(c))
        else: yield {".": 2, "-": 1, "~": -1}[c]
    yield 0

packages = {}

for filename in os.listdir(DEPENDENCIES):
    full_path = os.path.join(DEPENDENCIES, filename)
    if not filename.endswith("-osx.tar.gz"): continue
    if not os.path.isfile(full_path): continue

    parts = filename[:-11].split("-")
    for i in xrange(1, len(parts)):
        version = "-".join(parts[i:])
        if re.match("^([-.~0-9]+)$", version) is None: continue
        name = "-".join(parts[:i])
        if not packages.has_key(name): packages[name] = []
        packages[name].append((full_path, tuple(parse_version(version))))
        break

for name, candidates in packages.iteritems():
    candidates.sort(key=lambda x: x[1], reverse=True)
    print "Using %s to provide %s" % (os.path.basename(candidates[0][0]), name)
    for filename, _ in candidates[1:]:
        os.rename(filename, "%s.disabled" % filename)

END
