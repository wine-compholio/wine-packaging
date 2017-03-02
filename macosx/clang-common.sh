#!/bin/bash
#
# Install clang and dependencies
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

apt-get install -y libobjc4

dpkg -i /build/source/deps/gcc-5-base_5.4.1-4_amd64.deb \
        /build/source/deps/libgcc-5-dev_5.4.1-4_amd64.deb \
        /build/source/deps/libobjc-5-dev_5.4.1-4_amd64.deb

apt-get install -y libffi-dev binfmt-support libjsoncpp1

dpkg -i /build/source/deps/libclang-common-3.8-dev_3.8-2~stretch_amd64.deb \
        /build/source/deps/libclang1-3.8_3.8-2~stretch_amd64.deb \
        /build/source/deps/libllvm3.8_3.8-2~stretch_amd64.deb \
        /build/source/deps/llvm-3.8-dev_3.8-2~stretch_amd64.deb \
        /build/source/deps/llvm-3.8_3.8-2~stretch_amd64.deb \
        /build/source/deps/llvm-3.8-runtime_3.8-2~stretch_amd64.deb \
        /build/source/deps/clang-3.8_3.8-2~stretch_amd64.deb \
        /build/source/deps/clang_3.8-34~stretch_amd64.deb \
        /build/source/deps/llvm_3.8-34~stretch_amd64.deb \
        /build/source/deps/llvm-runtime_3.8-34~stretch_amd64.deb \
        /build/source/deps/llvm-dev_3.8-34~stretch_amd64.deb
