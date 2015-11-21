#!/usr/bin/python2
# -*- coding: utf-8 -*-
#
# Package file generator for Wine.
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

from email.Utils import formatdate
import copy

def __m(*x):
    u = copy.deepcopy(x[0])
    for v in x[1:]:
        u.update(v)
    return u

__devel_config = {
    "package" : "wine",
    "prefix"  : "/opt/wine-devel"
}

__staging_config = {
    "package" : "wine-staging",
    "prefix"  : "/opt/wine-staging"
}

__debian_base = {
    "__src"          : "debian",
    "ubuntu_version" : 0,
    "debian_version" : 0,
    "debian_codename": "",
    "debian_time"    : formatdate()
}

package_configs = {
    "debian-wheezy-development"  : __m(__devel_config,   __debian_base, dict(debian_version=7, debian_codename="wheezy")),
    "debian-wheezy-staging"      : __m(__staging_config, __debian_base, dict(debian_version=7, debian_codename="wheezy")),
    "debian-jessie-development"  : __m(__devel_config,   __debian_base, dict(debian_version=8, debian_codename="jessie")),
    "debian-jessie-staging"      : __m(__staging_config, __debian_base, dict(debian_version=8, debian_codename="jessie")),
    "debian-stretch-development" : __m(__devel_config,   __debian_base, dict(debian_version=9, debian_codename="stretch")),
    "debian-stretch-staging"     : __m(__staging_config, __debian_base, dict(debian_version=9, debian_codename="stretch")),
    "debian-sid-development"     : __m(__devel_config,   __debian_base, dict(debian_version=999, debian_codename="sid")),
    "debian-sid-staging"         : __m(__staging_config, __debian_base, dict(debian_version=999, debian_codename="sid")),

    "ubuntu-any-development"     : __m(__devel_config,   __debian_base, dict(ubuntu_version=999)),
    "ubuntu-any-staging"         : __m(__staging_config, __debian_base, dict(ubuntu_version=999))
}
