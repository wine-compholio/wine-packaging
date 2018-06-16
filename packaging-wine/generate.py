#!/usr/bin/python3
# -*- coding: utf-8 -*-

from email.utils import formatdate
import argparse
import tempfile
import subprocess
import shutil
import copy
import stat
import os
import re
import json
import base64
import sys
import hashlib

DEV_NULL = open(os.devnull, 'w')

def git_clone(output, version, repos, head=0):
    if not os.path.isdir(output):
        os.makedirs(output)

    if version.startswith("-"):
        raise RuntimeError("Tag/commit %s does not have valid format" % version)

    if version in ["HEAD", "master"]:
        repos = [repos[head]]

    # FIXME: Verify that tag is signed.
    assert not os.path.exists(os.path.join(output, ".git"))
    subprocess.check_call(["git", "init"], cwd=output, stdout=DEV_NULL)

    for repo in repos:
        print ("Trying to fetch %s from %s ..." % (version, repo))
        sys.stdout.flush()
        subprocess.check_call(["git", "remote", "add", "origin", repo], cwd=output)
        returncode = subprocess.call(["git", "fetch", "--depth=1", "origin", version], cwd=output)
        if returncode == 0: break
        subprocess.check_call(["git", "remote", "rm", "origin"], cwd=output)
    else:
        raise RuntimeError("Tag/commit %s not found in any repository" % version)

    subprocess.check_call(["git", "checkout", "-q", "FETCH_HEAD"], cwd=output)
    # shutil.rmtree(os.path.join(output, ".git"))

def is_wine_stable(version):
    if "-rc" in version:
        return False
    version = [int(v) for v in version.split(".")]
    if version[0] >= 2:
        return version[1] == 0
    else:
        return version[1] % 2 == 0

def hash_file(path, hasher_cls):
    hasher = hasher_cls()

    with open(path, 'rb') as f:
        buf = f.read(65536)
        while len(buf) > 0:
            hasher.update(buf)
            buf = f.read(65536)

    return hasher.hexdigest()

def prepare_sources(output, patches, settings):
    wine_version    = settings['wine_version']
    staging_version = settings.get('staging_version')
    package_release = settings.get('package_release')
    distribution    = settings.get('distribution')
    assert wine_version or staging_version

    if wine_version and '.' in wine_version and not wine_version.startswith("wine-"):
        wine_version = "wine-%s" % wine_version
    if staging_version and '.' in staging_version and not staging_version.startswith("v"):
        staging_version = "v%s" % staging_version
    if package_release and package_release <= 1:
        package_release = None

    if staging_version:
        git_clone(os.path.join(output, "staging"), staging_version,
                  ["https://github.com/wine-compholio/wine-staging.git",
                   "https://github.com/wine-staging/wine-staging.git"],
                  head=1) # Use fork mirror when building HEAD

    if not wine_version:
        wine_version = subprocess.check_output([os.path.join(output, "staging/patches/patchinstall.sh"),
                                               "--upstream-commit"]).decode('utf-8').strip()
        assert len(wine_version) >= 40 and wine_version.isalnum()

    git_clone(os.path.join(output, "wine"), wine_version,
              ["git://source.winehq.org/git/wine.git",
               "https://github.com/mstefani/wine-stable.git"])

    with open(os.path.join(output, "wine/VERSION")) as fp:
        version = fp.read().strip().split(" ")[-1]
        settings['package_version'] = version

    if staging_version:
        subprocess.check_call([os.path.join(output, "staging/patches/patchinstall.sh"),
                               "--backend=git-apply", "--all"], cwd=os.path.join(output, "wine"))

    if patches:
        hash_configure = hash_file(os.path.join(output, "wine/configure.ac"), hashlib.sha512)
        hash_protocol = hash_file(os.path.join(output, "wine/server/protocol.def"), hashlib.sha512)

        for f in sorted(os.listdir(patches)):
            print ("Applying %s" % os.path.join(patches, f))
            sys.stdout.flush()
            subprocess.check_call(["git", "apply", os.path.join(patches, f)],
                                  cwd=os.path.join(output, "wine"))

        if hash_configure != hash_file(os.path.join(output, "wine/configure.ac"), hashlib.sha512):
            print ("Running 'autoreconf -f'")
            sys.stdout.flush()
            subprocess.check_call(["autoreconf", "-f"], cwd=os.path.join(output, "wine"))

        if hash_protocol != hash_file(os.path.join(output, "wine/server/protocol.def"), hashlib.sha512):
            print ("Running './tools/make_requests'")
            sys.stdout.flush()
            subprocess.check_call(["./tools/make_requests"], cwd=os.path.join(output, "wine"))

    if staging_version:
        settings['package']         = "wine-staging"
        settings["compat_package"]  = "winehq-staging"
        settings["pretty_name"]     = "Wine Staging"
        settings["url"]             = "https://www.winehq.org/"
        settings["prefix"]          = "/opt/wine-staging"
        settings['stable']          = False
        settings['devel']           = True
        settings['staging']         = True

    elif is_wine_stable(version):
        settings['package']         = "wine-stable"
        settings["compat_package"]  = "winehq-stable"
        settings["pretty_name"]     = "Wine Stable"
        settings["url"]             = "https://www.winehq.org/"
        settings["prefix"]          = "/opt/wine-stable"
        settings['stable']          = True
        settings['devel']           = False
        settings['staging']         = False

    else:
        settings['package']         = "wine-devel"
        settings["compat_package"]  = "winehq-devel"
        settings["pretty_name"]     = "Wine Devel"
        settings["url"]             = "https://www.winehq.org/"
        settings["prefix"]          = "/opt/wine-devel"
        settings['stable']          = False
        settings['devel']           = True
        settings['staging']         = False

    if distribution in ['debian', 'ubuntu']:
        if "-rc" in version:
            assert version.count('.') == 1
            debian_version = version.replace("-rc", "~rc")
        else:
            assert version.count('.') <= 2
            debian_version = version + ".0" * (2 - version.count('.'))
        debian_version += "-%d" % package_release if package_release else ""
        debian_version += "~%s" % settings['%s_codename' % distribution]

        # "X.Y~rcZ-REL~CODENAME" or "X.Y.Z-REL~CODENAME"
        settings['debian_package_version'] = debian_version
        settings['debian_package_time']    = formatdate()

        if 'debian_version' not in settings:
            settings['debian_version'] = 0
        if 'ubuntu_version' not in settings:
            settings['ubuntu_version'] = 0

        # Ubuntu should use the same source as Debian
        distribution = 'debian'

    elif distribution in ['mageia', 'fedora']:
        if "-rc" in version:
            assert version.count('.') == 1
            fedora_version, fedora_release = version.split("-rc")
            fedora_release = "0.rc%s" % fedora_release
            fedora_release += ".%d" if package_release else ""
        else:
            assert version.count('.') <= 2
            fedora_version = version
            fedora_release = "%d" % package_release if package_release else "1"

        # ("X.Y", "0.rcZ.REL") or ("X.Y.Z", "REL")
        settings['%s_package_version' % distribution] = fedora_version
        settings['%s_package_release' % distribution] = fedora_release

        # Development package name is different on Mageia / Fedora
        if settings['package'] == "wine-devel":
            settings['package'] = "wine-development"

        if 'mageia_version' not in settings:
            settings['mageia_version'] = 0
        if 'fedora_version' not in settings:
            settings['fedora_version'] = 0

    elif distribution == 'macosx':
        macosx_version = version
        macosx_version += "-%d" % package_release if package_release else ""

        settings['macosx_package_name']    = settings['compat_package']
        settings['macosx_package_version'] = macosx_version

    else:
        raise NotImplementedError("Distribution %s not implemented yet" % distribution)

    return "./%s" % distribution

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

    if '__filename' not in namespace:
        namespace["__filename"] = os.path.basename(filename)

    local_namespace = {
        "include"          : lambda x: process_template(os.path.join(os.path.dirname(filename), x), namespace),
        "__content_blocks" : content_blocks,
        "__result"         : [],
    }

    exec("\n".join(compiled), namespace, local_namespace)
    return "".join(local_namespace["__result"])

def copy_files(source, output, settings):
    assert '__filename' not in settings

    if not os.path.isdir(output):
        os.makedirs(output)

    for filename in os.listdir(source):
        file_in  = os.path.join(source, filename)
        file_out = os.path.join(output, filename)

        if os.path.isdir(file_in):
            copy_files(file_in, file_out, settings)
            continue

        if file_in.endswith(".icns") or file_in.endswith(".png"):
            shutil.copy2(file_in, file_out)
            continue

        namespace = copy.deepcopy(settings)
        content = process_template(file_in, namespace)
        if namespace["__filename"] is None:
            continue

        file_out = os.path.join(output, namespace["__filename"])
        with open(file_out, 'w') as fp:
            fp.write(content)

        permissions = os.stat(file_in)[stat.ST_MODE]
        os.chmod(file_out, permissions)

def main():
    parser = argparse.ArgumentParser(description="Minimalistic build server")
    parser.add_argument('--config', help="Load configuration string", required=True)
    parser.add_argument('--patches', help="Apply patches from directory")
    parser.add_argument('output', help="Destination directory")
    args = parser.parse_args()

    if args.patches and not os.path.isdir(args.patches):
        raise RuntimeError("%s is not a directory" % args.patches)

    settings = json.loads(base64.b64decode(args.config.encode('utf-8')).decode('utf-8'))
    source = prepare_sources(args.output, args.patches, settings)
    copy_files(source, args.output, settings)

    exit(0)

if __name__ == "__main__":
    main()
