#!/usr/bin/python2
# -*- coding: utf-8 -*-
#
# Tool to create Mac OS X packages.
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
import errno
import magic
import os
import shutil
import stat
import subprocess
import tempfile
from lxml import etree

def get_or_create(root, name):
    node = root.find(name)
    if node is not None:
        return node
    return etree.SubElement(root, name)

def set_if_specified(node, name, value):
    if value is not None:
        node.set(name, value)

def create_empty_installer():
    root =  etree.Element("installer-script")
    root.set("minSpecVersion", "1.000000")

    # Hide that this is a selfmade python script ;-)
    root.set("authoringTool", "com.apple.PackageMaker")
    root.set("authoringToolVersion", "3.0.3")
    root.set("authoringToolBuild", "174")

    return root

def save_xml(root, path):
    with open(path, "w") as fp:
        fp.write(etree.tostring(root, xml_declaration=True, encoding='utf-8', pretty_print=True))

def load_installer(basedir):
    return etree.parse(os.path.join(basedir, "Distribution")).getroot()

def save_installer(root, basedir):
    return save_xml(root, os.path.join(basedir, "Distribution"))

def add_resource_file_node(basedir, root, nodename, path):
    full_path = os.path.join(basedir, "Resources", path)
    if not os.path.isfile(full_path):
        raise RuntimeError("%s does not exist" % full_path)

    m = magic.open(magic.MAGIC_MIME)
    m.load()

    mime_type = m.file(full_path)
    mime_type = mime_type.split(";", 1)[0]

    node = get_or_create(root, nodename)
    node.set("file", path)
    node.set("mime-type", mime_type)
    return node

def copy_files(src, dst):
    if not os.path.isdir(src):
        raise RuntimeError("Source path is not a directory")

    if not os.path.exists(dst):
        os.makedirs(dst)

    for filename in os.listdir(src):
        full_src = os.path.join(src, filename)
        full_dst = os.path.join(dst, filename)
        if os.path.isfile(full_src):
            shutil.copy2(full_src, full_dst)
        elif os.path.isdir(full_src):
            shutil.copytree(full_src, full_dst)
        else:
            raise RuntimeError("Found entry which is neither a file nor a directory")

def get_file_list(destdir, path):
    files = []
    size = 0

    for filename in sorted(os.listdir(os.path.join(destdir, path))):
        full_path = os.path.join(destdir, path, filename)
        rel_path = os.path.join(path, filename)

        if os.path.islink(full_path):
            files.append(rel_path)

        elif os.path.isfile(full_path):
            files.append(rel_path)
            size += 4 * ((os.path.getsize(full_path) + 4096 - 1)/4096)

        elif os.path.isdir(full_path):
            files.append(rel_path)
            sub_files, sub_size = get_file_list(destdir, rel_path)
            files += sub_files
            size += 4 + sub_size

    return files, size

def compress_payload(source_dir, filelist, archive):
    with tempfile.TemporaryFile(mode="r+b") as fin:
        fin.write("\n".join(filelist))
        fin.write("\n")
        fin.flush()
        fin.seek(0)
        cpio = subprocess.Popen(['cpio', '-o', "--format", "odc", "--owner", "0:80"], stdout=subprocess.PIPE, stdin=fin, cwd=source_dir)

    with open(archive, "wb") as fout:
        gzip = subprocess.Popen(['gzip', '-c'], stdin=cpio.stdout, stdout=fout)

    gzip.wait()
    cpio.wait()
    if gzip.returncode != 0:
        raise RuntimeError("gzip returned non zero exit code")
    if cpio.returncode != 0:
        raise RuntimeError("cpio returned non zero exit code")

def create_bom(source_dir, bom_file):
    subprocess.check_call(["mkbom", "-u", "0", "-g", "80", source_dir, bom_file])

def validate_installer(root):
    allowed_node_count = [
       #(node_name,             count,  unlimited_allowed)
        ("background",          [0,1],  False),
        ("choices-outline",     [1],    False),
        ("conclusion",          [0,1],  False),
        ("domains",             [0,1],  False),
        ("installation-check",  [0,1],  False),
        ("license",             [0,1],  False),
        ("options",             [0,1],  False),
        ("pkg-ref",             [1],    True),
        ("product",             [0,1],  False),
        ("readme",              [0,1],  False),
        ("script",              [0,1],  False),
        ("title",               [1],    False),
        ("volume-check",        [0,1],  False),
        ("welcome",             [0,1],  False),
    ]

    for node_name, counts, unlimited in allowed_node_count:
        c = len(root.findall(node_name))
        if c > 0 and unlimited:
            continue

        if c not in counts:
            raise RuntimeError("node %s must exist %s times" % (node_name, ",".join([str(x) for x in counts])))

    return True

def cmd_init(args):
    if not os.path.isdir(args.directory):
        raise RuntimeError("%s is not a directory" % args.directory)

    if len(os.listdir(args.directory)):
        raise RuntimeError("%s is not empty, refusing to create new package here" % args.directory)

    save_installer(create_empty_installer(), args.directory)

def cmd_settings(args):
    installer_xml = load_installer(args.directory)

    if args.title is not None:
        title = get_or_create(installer_xml, "title")
        title.text = args.title

    if args.background is not None:
        add_resource_file_node(args.directory, installer_xml, "background", args.background)

    if args.welcome is not None:
        add_resource_file_node(args.directory, installer_xml, "welcome", args.welcome)

    if args.conclusion is not None:
        add_resource_file_node(args.directory, installer_xml, "conclusion", args.conclusion)

    if args.architecture is not None:
        options = get_or_create(installer_xml, "options")
        options.set("hostArchitectures", ",".join(args.architecture))

    if args.allow_customization is not None:
        options = get_or_create(installer_xml, "options")
        options.set("customize", args.allow_customization)

    if args.allow_external_scripts is not None:
        options = get_or_create(installer_xml, "options")
        options.set("allow-external-scripts", args.allow_external_scripts)

    if args.target_any_volume is not None:
        domains = get_or_create(installer_xml, "domains")
        domains.set("enable_anywhere", args.target_any_volume)

    if args.target_user_home is not None:
        domains = get_or_create(installer_xml, "domains")
        domains.set("enable_currentUserHome", args.target_user_home)

    if args.target_local_system is not None:
        domains = get_or_create(installer_xml, "domains")
        domains.set("enable_localSystem", args.target_local_system)

    if args.installation_check is not None:
        installation_check = get_or_create(installer_xml, "installation-check")
        installation_check.set("script", args.installation_check)

    if args.script is not None:
        with open(args.script, "rb") as fp:
            script = get_or_create(installer_xml, "script")
            script.text = fp.read()

    save_installer(installer_xml, args.directory)

def cmd_resources(args):
    resources_path = os.path.join(args.directory, "Resources")

    if args.add is not None:
        copy_files(args.add, resources_path)

def cmd_pkg_add(args):
    pkg_path = os.path.join(args.directory, "%s.pkg" % args.identifier)
    if os.path.isdir(pkg_path) or os.path.isfile(pkg_path):
        raise RuntimeError("Directory %s already exists" % args.identifier)

    os.makedirs(pkg_path)

    payload_list, payload_size = get_file_list(args.payload, "")
    compress_payload(args.payload, payload_list, os.path.join(pkg_path, "Payload"))
    create_bom(args.payload, os.path.join(pkg_path, "BOM"))

    if args.scripts is not None:
        script_list, _ = get_file_list(args.scripts, "")
        compress_payload(args.scripts, script_list, os.path.join(pkg_path, "Scripts"))

    # Create pkg-info XML
    pkg_xml = etree.Element("pkg-info")
    pkg_xml.set("format-version", "2")
    pkg_xml.set("identifier", args.identifier)
    pkg_xml.set("version", args.version)
    pkg_xml.set("install-location", args.install_location)

    payload = etree.SubElement(pkg_xml, "payload")
    payload.set("installKBytes", "%d" % payload_size)
    payload.set("numberOfFiles", "%d" % len(payload_list))

    if args.preinstall_script is not None:
        if args.scripts is None or not os.path.isfile(os.path.join(args.scripts, args.preinstall_script)):
            raise RuntimeError("Preinstall script is not part of the script archive (or no script archive at all)")

        scripts = get_or_create(pkg_xml, "scripts")
        preinstall = get_or_create(scripts, "preinstall")
        preinstall.set("file", args.preinstall_script)

    if args.postinstall_script is not None:
        if args.scripts is None or not os.path.isfile(os.path.join(args.scripts, args.postinstall_script)):
            raise RuntimeError("Postinstall script is not part of the script archive (or no script archive at all)")

        scripts = get_or_create(pkg_xml, "scripts")
        postinstall = get_or_create(scripts, "postinstall")
        postinstall.set("file", args.postinstall_script)

    save_xml(pkg_xml, os.path.join(pkg_path, "PackageInfo"))

    # Add reference to installer-script
    installer_xml = load_installer(args.directory)

    pkg_ref = etree.SubElement(installer_xml, "pkg-ref")
    pkg_ref.set("id", args.identifier)
    pkg_ref.set("installKBytes", "%d" % payload_size)
    pkg_ref.set("version", args.version)
    # The # is important to signal that the directory is part of the archive
    pkg_ref.text = "#%s.pkg" % args.identifier

    if args.on_conclusion is not None:
        pkg_ref.set("onConclusion", args.on_conclusion)

    if args.on_conclusion_script is not None:
        pkg_ref.set("onConclusionScript", args.on_conclusion_script)

    if args.active is not None:
        pkg_ref.set("active", args.active)

    save_installer(installer_xml, args.directory)

def cmd_choice_add(args):
    installer_xml = load_installer(args.directory)

    choice = etree.SubElement(installer_xml, "choice")
    choice.set("id", args.id)
    choice.set("title", args.title)
    choice.set("description", args.description)
    set_if_specified(choice, "description-mime-type", args.description_mime)

    set_if_specified(choice, "customLocation", args.custom_location)
    if args.allow_any_volume is not None and args.custom_location is None:
        raise RuntimeError("--allow-any-volume is only valid if --custom-location is set")
    set_if_specified(choice, "customLocationAllowAlternateVolumes", args.allow_any_volume)

    set_if_specified(choice, "enabled", args.enabled)
    set_if_specified(choice, "selected", args.selected)
    set_if_specified(choice, "visible", args.visible)

    set_if_specified(choice, "start_enabled", args.start_enabled)
    set_if_specified(choice, "start_selected", args.start_selected)
    set_if_specified(choice, "start_visible", args.start_visible)

    for pkg_id in args.pkgs:
        pkg_ref = etree.SubElement(choice, "pkg-ref")
        pkg_ref.set("id", pkg_id)

    # Add choice to list of possible choices
    choices_outline = get_or_create(installer_xml, "choices-outline")
    line = etree.SubElement(choices_outline, "line")
    line.set("choice", args.id)

    save_installer(installer_xml, args.directory)

def cmd_generate(args):
    installer_xml = load_installer(args.directory)
    validate_installer(installer_xml)

    subprocess.check_call(["xar", "-C", args.directory, "--compression", "none", "-cf", args.output, "."])

if __name__ == '__main__':
    parser = argparse.ArgumentParser(description="Tool to create Mac OS X packages")
    parser.add_argument('-C', dest="directory", help="directory to operate on", default="./")
    subparsers = parser.add_subparsers(dest="command")

    init_parser = subparsers.add_parser('init')

    settings_parser = subparsers.add_parser('settings')
    settings_parser.add_argument('--title', help="title of installer", required=False)
    settings_parser.add_argument('--background', help="background file for installer", required=False)
    settings_parser.add_argument('--welcome', help="welcome file for installer", required=False)
    settings_parser.add_argument('--conclusion', help="conclusion file for installer", required=False)
    settings_parser.add_argument('--architecture', help="possible architectures (i386 includes x86_64)", nargs='+', required=False, choices=['i386', 'x86_64', 'ppc'])
    settings_parser.add_argument('--allow-customization', help="allow the user to change options", required=False, choices=['allow','always','never'])
    settings_parser.add_argument('--allow-external-scripts', help="enable run / runOnce JS functions", required=False, choices=['true','false'])
    settings_parser.add_argument('--target-any-volume', help="allow to install the package on any volume", required=False, choices=['true','false'])
    settings_parser.add_argument('--target-user-home', help="allow to install the package into home directory", required=False, choices=['true','false'])
    settings_parser.add_argument('--target-local-system', help="allow to install the package into a system directory", required=False, choices=['true','false'])
    settings_parser.add_argument('--installation-check', help="true or JS which evaluates to true or false", required=False)
    settings_parser.add_argument('--script', help="file to add as script", required=False)

    resources_parser = subparsers.add_parser('resources')
    resources_parser.add_argument('--add', help="files to copy to resources", required=False)

    pkg_add_parser = subparsers.add_parser('pkg-add')
    pkg_add_parser.add_argument('--identifier', help="identifier for package (com.example.program)", required=True)
    pkg_add_parser.add_argument('--version', help="version of package", required=True)
    pkg_add_parser.add_argument('--install-location', help="path where the package should be installed", required=True)
    pkg_add_parser.add_argument('--payload', help="directory which should be packaged as payload", required=True)
    pkg_add_parser.add_argument('--scripts', help="directory which should be packaged as scripts", required=False)
    pkg_add_parser.add_argument('--active', help="install this package (true/false/JS)", required=False)
    pkg_add_parser.add_argument('--on-conclusion', help="action on conclusion", choices=['None','RequireLogout','RequireRestart','RequireShutdown'], required=False)
    pkg_add_parser.add_argument('--on-conclusion-script', help="script to execute on conclusion (JS)", required=False)
    pkg_add_parser.add_argument('--preinstall-script', help="script to execute before installation (file)", required=False)
    pkg_add_parser.add_argument('--postinstall-script', help="script to execute after installation (file)", required=False)

    choice_add_parser = subparsers.add_parser('choice-add')
    choice_add_parser.add_argument('--id', help="identifier for choice", required=True)
    choice_add_parser.add_argument('--title', help="title for this option", required=True)
    choice_add_parser.add_argument('--description', help="description for this option", required=True)
    choice_add_parser.add_argument('--description-mime', help="mime type for description", required=False, choices=["text/plain", "text/rtf", "text/html"])
    choice_add_parser.add_argument('--pkgs', help="packages which should be installed for this option", required=True, nargs='+')
    choice_add_parser.add_argument('--custom-location', help="define a default installation location (can be changed by user)", required=False)
    choice_add_parser.add_argument('--allow-any-volume', help="user can change volume (requires custom location)", required=False)
    choice_add_parser.add_argument('--enabled', help="allow user to change option (true/false/JS)", required=False)
    choice_add_parser.add_argument('--selected', help="define if this option should be installed (true/false/JS)", required=False)
    choice_add_parser.add_argument('--visible', help="define if this option should be visible (true/false/JS)", required=False)
    choice_add_parser.add_argument('--start-enabled', help="should be enabled on start", required=False, choices=['true','false'])
    choice_add_parser.add_argument('--start-selected', help="should be selected on start", required=False, choices=['true','false'])
    choice_add_parser.add_argument('--start-visible', help="should be visible on start", required=False, choices=['true','false'])

    generate_parser = subparsers.add_parser('generate')
    generate_parser.add_argument('--output', help="path at which the new pkg should be generated", required=True)

    args = parser.parse_args()

    if args.command == "init":
        cmd_init(args)
    elif args.command == "settings":
        cmd_settings(args)
    elif args.command == "resources":
        cmd_resources(args)
    elif args.command == "pkg-add":
        cmd_pkg_add(args)
    elif args.command == "choice-add":
        cmd_choice_add(args)
    elif args.command == "generate":
        cmd_generate(args)
    else:
        raise NotImplementedError("Unimplemented comment?")
