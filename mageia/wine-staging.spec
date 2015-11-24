{{ __filename = "%s.spec" % package }}
# Maintainer: Sebastian Lackner, sebastian [at] fds-team [dot] de

{{
	rel = int(package_release) if package_release != "" else 0
	if "-rc" in package_version
		version, release = package_version.split("-rc", 1)
		release = "0.rc%s.%d" % (release, rel + 1)
	else
		version = package_version
		release = "%d" % (rel + 1)
	endif
}}

%define rel             {{ =release }}
%define lib_major       1
%define lib_name        %mklibname %{name} %{lib_major}
%define lib_name_devel  %{mklibname -d %{name}}
%define _fortify_cflags %nil

Name:       {{ =package }}
Version:    {{ =version }}
Release:    %mkrel %rel
Epoch:      1
Summary:    WINE Is Not An Emulator - runs MS Windows programs
License:    LGPLv2+
Group:      Emulators
{{ if staging }}
URL:        http://www.wine-staging.com/
Source0:    wine.tar.bz2
Source1:    wine-staging.tar.gz
{{ else }}
URL:        https://www.winehq.org/
Source0:    wine.tar.bz2
{{ endif }}

%ifarch x86_64
%define wine    %{name}64
%define mark64  ()(64bit)
%else
%define wine    %{name}
%define mark64  %{nil}
%endif

%define _prefix {{ =prefix }}
Prefix:         {{ =prefix }}

BuildRequires:  bison flex
BuildRequires:  gpm-devel
BuildRequires:  perl-devel
BuildRequires:  ncurses-devel
BuildRequires:  cups-devel
BuildRequires:  sane-devel
BuildRequires:  png-devel
BuildRequires:  lcms2-devel
BuildRequires:  autoconf
BuildRequires:  docbook-utils docbook-dtd-sgml sgml-tools
BuildRequires:  pulseaudio-devel
BuildRequires:  libmpg123-devel
BuildRequires:  openal-devel
BuildRequires:  icoutils
BuildRequires:  libalsa-devel
BuildRequires:  isdn4k-utils-devel
BuildRequires:  glibc-static-devel
BuildRequires:  chrpath
BuildRequires:  ungif-devel xpm-devel
BuildRequires:  tiff-devel
BuildRequires:  librsvg
BuildRequires:  imagemagick
BuildRequires:  gphoto2-devel
BuildRequires:  desktop-file-utils
BuildRequires:  openldap-devel
BuildRequires:  libxslt-devel
BuildRequires:  dbus-devel
BuildRequires:  valgrind-devel
BuildRequires:  gsm-devel
BuildRequires:  unixODBC-devel
BuildRequires:  gnutls-devel
BuildRequires:  prelink
BuildRequires:  gettext-devel
BuildRequires:  mesaglu-devel
BuildRequires:  libv4l-devel
BuildRequires:  libxcursor-devel libxcomposite-devel
BuildRequires:  libxinerama-devel libxrandr-devel
BuildRequires:  libx11-devel libxrender-devel
BuildRequires:  libxext-devel libsm-devel
BuildRequires:  fontforge fontconfig-devel freetype2-devel
BuildRequires:  libxi-devel
BuildRequires:  osmesa-devel
BuildRequires:  opencl-devel
BuildRequires:  attr-devel
BuildRequires:  libpcap-devel
BuildRequires:  gawk unzip coreutils util-linux

%ifarch x86_64
%package -n %{wine}
%endif
Summary:    WINE Is Not An Emulator - runs MS Windows programs
Group:      Emulators
%ifarch x86_64
Conflicts:  %{name}
%else
Conflicts:  %{name}64
%endif
Requires:   %{name}-common = %{epoch}:%{version}-%{release}
Provides:   %{lib_name} = %{epoch}:%{version}-%{release}
Obsoletes:  %{lib_name} <= %{epoch}:%{version}-%{release}
Provides:   %{name}-bin = %{epoch}:%{version}-%{release}

%ifarch %{ix86}
%package -n %{name}-common
Summary:    WINE Is Not An Emulator - runs MS Windows programs (32-bit common files)
Group:      Emulators
Requires:   %{name}-bin = %{epoch}:%{version}-%{release}
%endif

%define dlopenreq() %(F=/usr/%{_lib}/lib%{1}.so;[ -e $F ] && (file $F|grep -q ASCII && grep -o 'lib[^ ]*' $F|sed -e "s/\$/%{mark64}/"||objdump -p $F | grep SONAME | awk '{ print $2 "%{mark64}" }') || echo "wine-missing-buildrequires-on-%{1}")
Requires:   %dlopenreq freetype
Requires:   %dlopenreq asound
Requires:   %dlopenreq fontconfig
Requires:   %dlopenreq ncurses
Requires:   %dlopenreq Xrender
Requires:   %dlopenreq png
Requires:   %dlopenreq Xcursor
Requires:   %dlopenreq Xi
Requires:   %dlopenreq Xxf86vm
Requires:   %dlopenreq Xrandr
Requires:   %dlopenreq Xinerama
Requires:   %dlopenreq Xcomposite
Requires:   %dlopenreq xslt
Requires:   %dlopenreq dbus-1
Requires:   %dlopenreq gnutls
Requires:   %dlopenreq sane
Requires:   %dlopenreq v4l1
Requires:   %dlopenreq cups
Requires:   %dlopenreq ssl
Requires:   %dlopenreq crypto
Requires:   %dlopenreq gsm
Requires:   %dlopenreq jpeg
Requires:   %dlopenreq tiff
Requires:   %dlopenreq odbc
Requires:   %dlopenreq OSMesa
Requires:   %dlopenreq attr
Suggests:   sane-frontends
Requires(post): desktop-file-utils
Requires(postun): desktop-file-utils
Requires(post): desktop-common-data
Requires(postun): desktop-common-data
Requires(preun): rpm-helper
Requires(post): rpm-helper

%define desc Wine is a program which allows running Microsoft Windows programs \
(including DOS, Windows 3.x and Win32 executables) on Unix. It \
consists of a program loader which loads and executes a Microsoft \
Windows binary, and a library (called Winelib) that implements Windows \
API calls using their Unix or X11 equivalents.  The library may also \
be used for porting Win32 code into native Unix executables.

%description
%desc

%ifarch x86_64
%description -n %{wine}
%desc
%else
%description -n %{name}-common
Wine is a program which allows running Microsoft Windows programs
(including DOS, Windows 3.x and Win32 executables) on Unix.

This package contains the files needed to support 32-bit Windows
programs, and is used by both %{name} and %{name}64.
%endif

%package -n %{wine}-devel
Summary:    Static libraries and headers for %{name} (64-bit)
Group:      Development/C
Requires:   %{wine} = %{epoch}:%{version}-%{release}
%ifarch x86_64
Conflicts:  %{name}-devel
%else
Conflicts:  %{name}64-devel
%endif
Provides:   %{lib_name_devel} = %{epoch}:%{version}-%{release}
Obsoletes:  %{lib_name_devel} <= %{epoch}:%{version}-%{release}
%description -n %{wine}-devel
Wine is a program which allows running Microsoft Windows programs
(including DOS, Windows 3.x and Win32 executables) on Unix.

This package contains the libraries and header files needed to
develop programs which make use of wine.

%package -n {{ =compat_package }}
Summary:    WINE Is Not An Emulator - runs MS Windows programs
Group:      Emulators
Requires:   %{wine} = %{epoch}:%{version}-%{release}
Conflicts:  wine wine64

%description -n {{ =compat_package }}
Wine is a program which allows running Microsoft Windows programs
(including DOS, Windows 3.x and Win32 executables) on Unix.

This compatibility package allows to use %{wine} system-wide as
the default wine version.

%prep
%setup -q -T -c -n wine-%{version}
tar -xvf "%{SOURCE0}" --strip-components 1
{{ if staging }}
tar -xvf "%{SOURCE1}" --strip-components 1
make -C "patches" DESTDIR="%{_builddir}/wine-%{version}" install
{{ endif }}

%build
%ifarch %{ix86}
export CFLAGS="%{optflags} -fno-omit-frame-pointer"
%endif
%configure2_5x \
    --with-x \
    --without-gstreamer \
{{ if staging }}
    --with-xattr \
    --without-gtk3 \
{{ endif }}
%ifarch x86_64
    --enable-win64 \
%endif
    --disable-tests
%make

%install
%makeinstall_std LDCONFIG=/bin/true

# Create compatibility symlinks
mkdir -p "%{buildroot}/usr/bin"
for _file in $(ls "%{buildroot}/%{_bindir}"); do \
    ln -s "%{_bindir}/$_file" "%{buildroot}/usr/bin/$_file"; \
done
mkdir -p "%{buildroot}/usr/share/applications"
for _file in $(ls "%{buildroot}/%{_datadir}/applications"); do \
    ln -s "%{_datadir}/applications/$_file" "%{buildroot}/usr/share/applications/$_file"; \
done
for _dir in man1 de.UTF-8/man1 fr.UTF-8/man1 pl.UTF-8/man1; do \
    mkdir -p "%{buildroot}/usr/share/man/$_dir"; \
    for _file in $(ls "%{buildroot}/%{_mandir}/$_dir"); do \
        ln -s "%{_mandir}/$_dir/$_file" "%{buildroot}/usr/share/man/$_dir/$_file"; \
    done; \
done
%ifarch x86_64
for _file in wine wine-preloader; do \
    ln -s "%{_prefix}/bin/$_file" "%{buildroot}/usr/bin/$_file"; \
done
for _dir in man1 de.UTF-8/man1 fr.UTF-8/man1 pl.UTF-8/man1; do \
    mkdir -p "%{buildroot}/usr/share/man/$_dir"; \
    ln -s "%{_mandir}/$_dir/wine.1" "%{buildroot}/usr/share/man/$_dir/wine.1"; \
done
%endif

%files -n %{wine}
%doc ANNOUNCE AUTHORS README
%ifarch x86_64
%{_bindir}/wine64
%{_bindir}/wine64-preloader
%endif
%{_bindir}/winecfg
%{_bindir}/wineconsole*
%{_bindir}/wineserver
%{_bindir}/wineboot
%{_bindir}/function_grep.pl
%{_bindir}/msiexec
{{ if staging }}
%{_bindir}/msidb
{{ endif }}
%{_bindir}/notepad
%{_bindir}/regedit
%{_bindir}/winemine
%{_bindir}/winepath
%{_bindir}/regsvr32
%{_bindir}/winefile
%lang(de) %{_mandir}/de.UTF-8/man?/winemaker.?*
%lang(de) %{_mandir}/de.UTF-8/man?/wineserver.?*
%lang(fr) %{_mandir}/fr.UTF-8/man?/winemaker.?*
%lang(fr) %{_mandir}/fr.UTF-8/man?/wineserver.?*
%{_mandir}/man?/wineserver.?*
%{_mandir}/man?/msiexec.?*
%{_mandir}/man?/notepad.?*
%{_mandir}/man?/regedit.?*
%{_mandir}/man?/regsvr32.?*
%{_mandir}/man?/wineboot.?*
%{_mandir}/man?/winecfg.?*
%{_mandir}/man?/wineconsole.?*
%{_mandir}/man?/winefile.?*
%{_mandir}/man?/winemine.?*
%{_mandir}/man?/winepath.?*
%dir %{_datadir}/wine
%{_datadir}/wine/wine.inf
%{_datadir}/wine/l_intl.nls
%{_datadir}/applications/*.desktop
%dir %{_datadir}/wine/fonts
%{_datadir}/wine/fonts/*

%ifarch %{ix86}
%files -n %{name}-common
%{_bindir}/wine
%{_bindir}/wine-preloader
%{_mandir}/man?/wine.?*
%lang(de) %{_mandir}/de.UTF-8/man?/wine.?*
%lang(fr) %{_mandir}/fr.UTF-8/man?/wine.?*
%lang(pl) %{_mandir}/pl.UTF-8/man?/wine.?*
%endif

%{_libdir}/libwine*.so.%{lib_major}*
%dir %{_libdir}/wine
%{_libdir}/wine/*.cpl.so
%{_libdir}/wine/*.drv.so
%{_libdir}/wine/*.dll.so
%{_libdir}/wine/*.exe.so
%{_libdir}/wine/*.acm.so
%{_libdir}/wine/*.ocx.so
%ifarch %{ix86}
%{_libdir}/wine/*.vxd.so
%{_libdir}/wine/*16.so
%endif
%{_libdir}/wine/*.tlb.so
%{_libdir}/wine/*.ds.so
%{_libdir}/wine/*.sys.so
%{_libdir}/wine/fakedlls

%files -n %{wine}-devel
%{_libdir}/wine/*.a
%{_libdir}/libwine*.so
%{_libdir}/wine/*.def
%{_includedir}/*
%{_bindir}/wmc
%{_bindir}/wrc
%{_bindir}/winebuild
%{_bindir}/winegcc
%{_bindir}/wineg++
%{_bindir}/winecpp
%{_bindir}/widl
%{_bindir}/winedbg
%{_bindir}/winemaker
%{_bindir}/winedump
%{_mandir}/man1/wmc.1*
%{_mandir}/man1/wrc.1*
%{_mandir}/man1/winebuild.1*
%{_mandir}/man1/winemaker.1*
%{_mandir}/man1/winedump.1*
%{_mandir}/man1/widl.1*
%{_mandir}/man1/winedbg.1*
%{_mandir}/man1/wineg++.1*
%{_mandir}/man1/winegcc.1*
%{_mandir}/man1/winecpp.1*

%files -n {{ =compat_package }}
/usr/bin/*
/usr/share/*
