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

import argparse
import copy
import os
import re
import shutil
import stat
import subprocess

import config

download_queue = {}

def process_template(content, namespace):
    content_blocks = []
    compiled = []
    controlstack = []
    only_control = False

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
                    only_control = False

                elif line.startswith("="):
                    compiled.append("%s__result.append(%s)" % (indent, line[1:]))
                    only_control = False

                elif not line.startswith("#"):
                    compiled.append("%s%s" % (indent, line))

    assert len(controlstack) == 0
    namespace["__content_blocks"] = content_blocks
    namespace["__result"] = []
    exec "\n".join(compiled) in namespace
    return "".join(namespace["__result"])

def copy_files(src, dst, namespace_template):
    if not os.path.isdir(dst):
        os.makedirs(dst)

    for filename in os.listdir(src):
        file_in  = os.path.join(src, filename)
        file_out = os.path.join(dst, filename)

        if os.path.isfile(file_in):
            downloads = []
            namespace = copy.deepcopy(namespace_template)
            namespace["__filename"]     = filename
            namespace["os"]             = os
            namespace["download"]       = lambda x, y: downloads.append((x, y))

            with open(file_in, 'r') as fp:
                content = fp.read()

            content = process_template(content, namespace)
            if namespace["__filename"] is None: continue

            for (name, url) in downloads:
                if not download_queue.has_key(url):
                    download_queue[url] = []
                download_queue[url].append(os.path.join(dst, name))

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
    if not config.package_configs.has_key(distro):
        raise RuntimeError("%s is not a supported distro" % distro)

    namespace = copy.deepcopy(config.package_configs[distro])
    namespace["package_version"] = version
    namespace["package_release"] = release
    namespace["package_daily"]   = daily
    namespace["package_boot"]    = boot

    root_directory = os.path.join(os.path.dirname(os.path.realpath(__file__)), "./..")
    copy_files(os.path.join(root_directory, namespace["__src"]), dst, namespace)

if __name__ == '__main__':
    parser = argparse.ArgumentParser(description="Package file generator for Wine")
    parser.add_argument('--ver', help="Wine version to build", required=True)
    parser.add_argument("--rel", help="Release number of this build", default="")
    parser.add_argument('--out', help="Output directory for build files", required=True)
    parser.add_argument('--daily', action='store_true', help="Generate build files for a daily build")
    parser.add_argument('--boot', action='store_true', help="Generate boot script and download dependencies")
    parser.add_argument('--skip-name', action='store_true', help="Skip distro name in output directory (works only for one distro)")
    parser.add_argument('distribution', nargs="*", help="List of distros to create packaging files for")
    args = parser.parse_args()

    if len(args.distribution) == 0:
        args.distribution = config.package_configs.keys()

    for distro in args.distribution:
        if not config.package_configs.has_key(distro):
            raise RuntimeError("%s is not a supported distro" % distro)

    if args.skip_name and len(args.distribution) != 1:
        raise RuntimeError("--skip-name can only be used with one distro")

    for distro in args.distribution:
        dst = args.out if args.skip_name else os.path.join(args.out, distro)
        generate_package(distro, args.ver, args.rel, args.daily, args.boot, dst)

    for url, filenames in download_queue.iteritems():
        subprocess.call(["curl", "-o", filenames[0], "--", url])
        for filename in filenames[1:]:
            shutil.copyfile(filenames[0], filename)
