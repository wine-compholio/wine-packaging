#!/usr/bin/python2
# -*- coding: utf-8 -*-
#
# Package file generator for Wine.
#
# Copyright (C) 2015 Michael Müller
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

from email.Utils import formatdate
import argparse
import copy
import hashlib
import os
import re
import shutil
import stat
import subprocess
import tempfile

def _m(*x):
    u = copy.deepcopy(x[0])
    for v in x[1:]:
        u.update(v)
    return u

WINE_STABLE_CONFIG = {
    "__src"             : "wine",
    "package"           : "wine-stable",
    "compat_package"    : "winehq-stable",
    "prefix"            : "/opt/wine-stable",
    "staging"           : False,
    "devel"             : False,
}

WINE_DEVEL_CONFIG = {
    "__src"             : "wine",
    "package"           : "wine-devel",
    "compat_package"    : "winehq-devel",
    "prefix"            : "/opt/wine-devel",
    "staging"           : False,
    "devel"             : True,
}

WINE_STAGING_CONFIG = {
    "__src"             : "wine",
    "package"           : "wine-staging",
    "compat_package"    : "winehq-staging",
    "prefix"            : "/opt/wine-staging",
    "staging"           : True,
    "devel"             : True,
}

CLANG_CONFIG = {
    "__src"             : "clang-native",
    "package"           : "clang",
}

BOMUTILS_CONFIG = {
    "__src"             : "bomutils-native",
    "package"           : "bomutils",
}

CCTOOLS_CONFIG = {
    "__src"             : "cctools-native",
    "package"           : "cctools",
}

XAR_CONFIG = {
    "__src"             : "xar-native",
    "package"           : "xar",
}

LIBJPEG_TURBO_CONFIG = {
    "__src"             : "libjpeg-turbo",
    "package"           : "libjpeg-turbo",
}

LIBTIFF_CONFIG = {
    "__src"             : "libtiff",
    "package"           : "libtiff",
}


DEBIAN_BASE = {
    "distribution"   : "debian",
    "ubuntu_version" : 0,
    "debian_version" : 0,
    "debian_codename": "",
    "debian_time"    : formatdate(),
}

MACOSX_BASE = {
    "distribution"   : "macosx",
    "ubuntu_version" : 0,
    "debian_version" : 8,
    "debian_codename": "jessie",
    "debian_time"    : formatdate()
}

MAGEIA_BASE = {
    "distribution"   : "mageia",
    "mageia_version" : 0,
}

FEDORA_BASE = {
    "distribution"   : "fedora",
    "fedora_version" : 0,
}

PACKAGE_CONFIGS = {
    # Debian Wheezy
    "debian-wheezy-stable"       : _m( WINE_STABLE_CONFIG,  DEBIAN_BASE, dict(debian_version=7,   debian_codename="wheezy") ),
    "debian-wheezy-development"  : _m( WINE_DEVEL_CONFIG,   DEBIAN_BASE, dict(debian_version=7,   debian_codename="wheezy") ),
    "debian-wheezy-staging"      : _m( WINE_STAGING_CONFIG, DEBIAN_BASE, dict(debian_version=7,   debian_codename="wheezy") ),

    # Debian Jessie
    "debian-jessie-stable"       : _m( WINE_STABLE_CONFIG,  DEBIAN_BASE, dict(debian_version=8,   debian_codename="jessie") ),
    "debian-jessie-development"  : _m( WINE_DEVEL_CONFIG,   DEBIAN_BASE, dict(debian_version=8,   debian_codename="jessie") ),
    "debian-jessie-staging"      : _m( WINE_STAGING_CONFIG, DEBIAN_BASE, dict(debian_version=8,   debian_codename="jessie") ),

    # Debian Stretch
    "debian-stretch-stable"      : _m( WINE_STABLE_CONFIG,  DEBIAN_BASE, dict(debian_version=9,   debian_codename="stretch") ),
    "debian-stretch-development" : _m( WINE_DEVEL_CONFIG,   DEBIAN_BASE, dict(debian_version=9,   debian_codename="stretch") ),
    "debian-stretch-staging"     : _m( WINE_STAGING_CONFIG, DEBIAN_BASE, dict(debian_version=9,   debian_codename="stretch") ),

    # Debian Sid
    "debian-sid-stable"          : _m( WINE_STABLE_CONFIG,  DEBIAN_BASE, dict(debian_version=999, debian_codename="sid") ),
    "debian-sid-development"     : _m( WINE_DEVEL_CONFIG,   DEBIAN_BASE, dict(debian_version=999, debian_codename="sid") ),
    "debian-sid-staging"         : _m( WINE_STAGING_CONFIG, DEBIAN_BASE, dict(debian_version=999, debian_codename="sid") ),

    # Ubuntu
    "ubuntu-any-stable"          : _m( WINE_STABLE_CONFIG,  DEBIAN_BASE, dict(ubuntu_version=1) ),
    "ubuntu-any-development"     : _m( WINE_DEVEL_CONFIG,   DEBIAN_BASE, dict(ubuntu_version=1) ),
    "ubuntu-any-staging"         : _m( WINE_STAGING_CONFIG, DEBIAN_BASE, dict(ubuntu_version=1) ),

    # Mageia
    "mageia-any-stable"          : _m( WINE_STABLE_CONFIG,  MAGEIA_BASE, dict(mageia_version=1) ),
    "mageia-any-development"     : _m( WINE_DEVEL_CONFIG,   MAGEIA_BASE, dict(mageia_version=1, package="wine-development") ),
    "mageia-any-staging"         : _m( WINE_STAGING_CONFIG, MAGEIA_BASE, dict(mageia_version=1) ),

    # Fedora
    "fedora-any-stable"          : _m( WINE_STABLE_CONFIG,  FEDORA_BASE, dict(fedora_version=1) ),
    "fedora-any-development"     : _m( WINE_DEVEL_CONFIG,   FEDORA_BASE, dict(fedora_version=1, package="wine-development") ),
    "fedora-any-staging"         : _m( WINE_STAGING_CONFIG, FEDORA_BASE, dict(fedora_version=1) ),

    # Mac OS X
    "macosx-clang-native"        : _m( CLANG_CONFIG,        MACOSX_BASE ),
    "macosx-bomutils-native"     : _m( BOMUTILS_CONFIG,     MACOSX_BASE ),
    "macosx-cctools-native"      : _m( CCTOOLS_CONFIG,      MACOSX_BASE ),
    "macosx-xar-native"          : _m( XAR_CONFIG,          MACOSX_BASE ),
    "macosx-libjpeg-turbo"       : _m( LIBJPEG_TURBO_CONFIG,MACOSX_BASE ),
    "macosx-libtiff"             : _m( LIBTIFF_CONFIG,      MACOSX_BASE ),
}


download_queue = {}

def process_template(filename, namespace):
    content_blocks = []
    compiled = ["global __filename"]
    controlstack = []
    only_control = False

    with open(filename, 'r') as fp:
        content = fp.read()

    for i, block in enumerate(re.split("{{(.*?)}}", content, flags=re.DOTALL)):
        if i % 2 == 0:
            if only_control and block.startswith("\n"):
                block = block[1:]
            if block == "":
                only_control = True
                continue
            indent = "    " * len(controlstack)
            content_blocks.append(block)
            compiled.append("%s__result.append(__content_blocks[%d])" %
                            (indent, len(content_blocks) - 1))
            only_control = block.endswith("\n")

        else:
            for line in block.split("\n"):
                line = line.strip()
                indent = "    " * len(controlstack)
                assert not line.endswith("\\")

                if line.startswith("if "):
                    compiled.append("%sif %s:" % (indent, line[3:]))
                    controlstack.append("if")

                elif line.startswith("elif "):
                    assert controlstack[-1] == "if"
                    compiled.append("%spass" % (indent,))
                    compiled.append("%selif %s:" %
                                    ("    " * (len(controlstack) - 1), line[5:]))

                elif line == "else":
                    assert controlstack[-1] == "if"
                    compiled.append("%spass" % (indent,))
                    compiled.append("%selse:" % ("    " * (len(controlstack) - 1),))

                elif line == "endif":
                    assert controlstack.pop() == "if"
                    compiled.append("%spass" % (indent,))

                elif line.startswith("for "):
                    compiled.append("%sfor %s:" % (indent, line[4:]))
                    controlstack.append("for")

                elif line == "endfor":
                    assert controlstack.pop() == "for"
                    compiled.append("%spass" % (indent,))

                elif line.startswith("while "):
                    compiled.append("%swhile %s:" % (indent, line[6:]))
                    controlstack.append("while")

                elif line == "endwhile":
                    assert controlstack.pop() == "while"
                    compiled.append("%spass" % (indent,))

                elif line.startswith("print "):
                    compiled.append("%s__result.append(%s)" % (indent, line[6:]))

                elif line.startswith("="):
                    compiled.append("%s__result.append(%s)" % (indent, line[1:]))

                elif not line.startswith("#"):
                    compiled.append("%s%s" % (indent, line))

    assert len(controlstack) == 0

    if not namespace.has_key("__filename"):
        namespace["__filename"] = os.path.basename(filename)

    local_namespace = {
        "include"          : lambda x: process_template(os.path.join(os.path.dirname(filename), x), namespace),
        "__content_blocks" : content_blocks,
        "__result"         : [],
    }

    exec "\n".join(compiled) in namespace, local_namespace
    return "".join(local_namespace["__result"])

def copy_files(src, dst, namespace_template):
    if not os.path.isdir(dst):
        os.makedirs(dst)

    for filename in os.listdir(src):
        file_in  = os.path.join(src, filename)
        file_out = os.path.join(dst, filename)

        if os.path.isfile(file_in):
            downloads = []
            namespace = copy.deepcopy(namespace_template)
            namespace["os"]             = os
            namespace["download"]       = lambda name, url, sha=None: downloads.append((name, url, sha))
            assert not namespace.has_key("__filename")

            content = process_template(file_in, namespace)
            if namespace["__filename"] is None: continue

            for name, url, sha in downloads:
                if not download_queue.has_key(url):
                    download_queue[url] = []
                download_queue[url].append((os.path.join(dst, name), sha))

            file_out = os.path.join(dst, namespace["__filename"])
            with open(file_out, 'w') as fp:
                fp.write(content)

        elif os.path.isdir(file_in):
            copy_files(file_in, file_out, namespace_template)

        else:
            raise RuntimeError("Found entry which is neither a file nor a directory")

        # Copy file permissions to make sure we don't remove execute permissions
        permissions = os.stat(file_in)[stat.ST_MODE]
        os.chmod(file_out, permissions)

def generate_package(distro, version, release, daily, boot, dst):
    if not PACKAGE_CONFIGS.has_key(distro):
        raise RuntimeError("%s is not a supported distro" % distro)

    namespace = copy.deepcopy(PACKAGE_CONFIGS[distro])
    namespace["package_version"] = version
    namespace["package_release"] = release
    namespace["package_daily"]   = daily
    namespace["package_boot"]    = boot

    root_directory = os.path.dirname(os.path.realpath(__file__))
    src = os.path.join(os.path.join(root_directory, namespace["distribution"]), namespace["__src"])
    copy_files(src, dst, namespace)

if __name__ == '__main__':
    parser = argparse.ArgumentParser(description="Package file generator for Wine")
    parser.add_argument('--ver', help="Wine version to build", required=True)
    parser.add_argument('--rel', help="Release number of this build", default="")
    parser.add_argument('--out', help="Output directory for build files", required=True)
    parser.add_argument('--daily', action='store_true', help="Generate build files for a daily build")
    parser.add_argument('--boot', action='store_true', help="Generate boot script and download dependencies")
    parser.add_argument('--skip-name', action='store_true', help="Skip distro name in output directory (works only for one distro)")
    parser.add_argument('distribution', nargs="*", help="List of distros to create packaging files for")
    args = parser.parse_args()

    if len(args.distribution) == 0:
        args.distribution = PACKAGE_CONFIGS.keys()

    for distro in args.distribution:
        if not PACKAGE_CONFIGS.has_key(distro):
            raise RuntimeError("%s is not a supported distro" % distro)

    if args.skip_name and len(args.distribution) != 1:
        raise RuntimeError("--skip-name can only be used with one distro")

    for distro in args.distribution:
        dst = args.out if args.skip_name else os.path.join(args.out, distro)
        generate_package(distro, args.ver, args.rel, args.daily, args.boot, dst)

    for url, filenames in download_queue.iteritems():
        fp = None
        try:
            fp = tempfile.NamedTemporaryFile(prefix="download-", delete=False)
            fp.close()

            subprocess.call(["curl", "-L", "-o", fp.name, "--", url])

            m = hashlib.sha256()
            with open(fp.name, "rb") as fp2:
                while True:
                    buf = fp2.read(16384)
                    if buf == "": break
                    m.update(buf)
            found_sha = m.hexdigest()

            for filename, sha in filenames:
                assert sha is None or sha == found_sha
                shutil.copyfile(fp.name, filename)

        finally:
            if fp is not None:
                os.unlink(fp.name)

    exit(0)
