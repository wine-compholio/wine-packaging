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
import stat

import config

def process_template(content, namespace):
    content_blocks = []
    compiled = []
    controlstack = []
    only_control = False

    for i, block in enumerate(re.split("{{(.*?)}}", content)):
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

                else:
                    compiled.append("%s%s" % (indent, line))

    assert len(controlstack) == 0

    namespace["__content_blocks"] = content_blocks
    namespace["__result"] = []
    exec "\n".join(compiled) in namespace
    return "".join(namespace["__result"])

def copy_files(src, dst, variable_replace):
    if not os.path.isdir(dst):
        os.makedirs(dst)

    for filename in os.listdir(src):
        file_in  = os.path.join(src, filename)
        file_out = os.path.join(dst, filename)

        if os.path.isfile(file_in):
            namespace = copy.deepcopy(variable_replace)
            namespace["__path"]         = file_out
            namespace["__directory"]    = dst
            namespace["__filename"]     = filename
            namespace["os"]             = os

            with open(file_in, 'r') as fp:
                content = fp.read()

            content = process_template(content, namespace)
            file_out = namespace["__path"]

            with open(file_out, 'w') as fp:
                fp.write(content)

        elif os.path.isdir(file_in):
            copy_files(file_in, file_out, variable_replace)

        else:
            raise RuntimeError("Found entry which is neither a file nor a directory")

        # Copy file permissions to make sure we don't remove execute permissions
        permissions = os.stat(file_in)[stat.ST_MODE]
        os.chmod(file_out, permissions)

if __name__ == '__main__':

    parser = argparse.ArgumentParser(description="Package file generator for Wine")
    parser.add_argument('--version', help="Wine version to build", required=True)
    parser.add_argument('--out', help="Output directory for build files", required=True)
    parser.add_argument('--distros', help="List of distros to create packaging files for")
    parser.add_argument('--skip-name', action='store_true', help="Skip distro name in output directory (works only for one distro)")

    args = parser.parse_args()
    outdir = os.path.abspath(args.out)

    # check if we got a list of valid distros
    if args.distros is not None:
        distros = [x.strip() for x in args.distros.split(",")]
        for distro in distros:
            if distro not in config.package_configs:
                raise RuntimeError("%s is not a supported distro" % distro)
    else:
        distros = config.package_configs.keys()

    if args.skip_name and len(distros) > 1:
        raise RuntimeError("--skip-name can only be used with one distro" % distro)

    tools_directory = os.path.dirname(os.path.realpath(__file__))
    os.chdir(os.path.join(tools_directory, "./.."))

    for distro in distros:
        namespace = copy.deepcopy(config.package_configs[distro])
        namespace["package_version"] = args.version
        distro_out = outdir
        if not args.skip_name:
            distro_out = os.path.join(distro_out, distro)
        copy_files(namespace["__src"], distro_out, namespace)
