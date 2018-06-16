#!/usr/bin/python3

import os
import re
import argparse
import subprocess

def parse_subversion(v):
    for i, c in enumerate(re.split("([0-9]+)", v)):
        if i % 2 == 0:
            yield c
        else:
            yield int(c)

def parse_version(v):
    for i, c in enumerate(re.split("([-.~])", v)):
        if i % 2 == 0:
            yield tuple(parse_subversion(c))
        else:
            yield {".": 2, "-": 1, "~": -1}[c]
    yield 0

def install_package(package, depdir, destdir, universal=False, filelist=None):
    candidates = []

    for filename in os.listdir(depdir):
        if not filename.startswith(package + "-"):
            continue

        fullpath = os.path.join(depdir, filename)
        if not os.path.isfile(fullpath):
            continue

        postfix = "-osx64.tar.gz" if universal else "-osx.tar.gz"
        if not filename.endswith(postfix):
            continue

        version_str = filename[len(package)+1:-len(postfix)]
        version = tuple(parse_version(version_str))

        candidates.append((fullpath, version, version_str))

    if not len(candidates):
        raise RuntimeError("Could not find package %s", package)

    candidates = sorted(candidates, key=lambda x: x[1], reverse=True)

    fullpath, version, version_str = candidates[0]
    print ("Installing %s version %s from %s" % (package, version_str, fullpath))

    with open(filelist, "a") as fp:
        subprocess.check_call(["tar", "--no-same-owner", "-C", destdir, "-xvf", fullpath], stdout=fp)

def main():
    parser = argparse.ArgumentParser(description="OSX dependency installer")
    parser.add_argument('--universal', action='store_true', help="install 64/32 bit universal dependencies")
    parser.add_argument('--depdir', help="directory containing the dependencies", default="/build/deps/macosx")
    parser.add_argument('--destdir', help="directory in which the dependencies get installed", default="/build/macos-rootfs")
    parser.add_argument('--filelist', help="append list of package content to this file", default="/build/deps/filelist.txt")
    parser.add_argument('packages', nargs='+')

    args = parser.parse_args()

    for package in args.packages:
        install_package(package, args.depdir, args.destdir, universal=args.universal, filelist=args.filelist)

if __name__ == '__main__':
    main()
