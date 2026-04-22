{ stdenv
, lib
, fetchurl
, autoPatchelfHook
, rpm
, cpio
, makeWrapper
, systemd
, hicolor-icon-theme
, desktop-file-utils
, shared-mime-info
, xorg
, wayland
, libglvnd
, libcap
, zstd
, pcre
, libgcrypt
, krb5
, e2fsprogs
, libpng
, libbsd
, lz4
, xz
, dbus
, glib
, icu
, fontconfig
, freetype
, libxkbcommon
, libdrm
, libxshmfence
, libunwind
, xkeyboard_config
, coreutils
, happd
, ...
}:

let
  version = "2.7.0";
  src = fetchurl {
    url = "https://github.com/Happ-proxy/happ-desktop/releases/download/${version}/Happ.linux.x64.rpm";
    hash = "sha256-QXRiTZraaOcjFDiyMnpXLQWuBfz7LjwGtEzk6fEdyPU=";
    name = "happ-proxy.rpm";
  };
in
stdenv.mkDerivation {
  pname = "happ";
  inherit version src;

  nativeBuildInputs = [
    autoPatchelfHook
    makeWrapper
    rpm
    cpio
    hicolor-icon-theme
    desktop-file-utils
    shared-mime-info
    coreutils
  ];

  buildInputs = [
    happd
    stdenv.cc.cc.lib
    xorg.libxcb
    xorg.xcbutil
    xorg.xcbutilimage
    xorg.xcbutilkeysyms
    xorg.xcbutilrenderutil
    xorg.xcbutilwm
    xorg.libXau
    xorg.libXdmcp
    wayland
    libglvnd
    libcap
    zstd
    pcre
    libgcrypt
    krb5
    e2fsprogs
    libpng
    libbsd
    lz4
    xz
    dbus
    glib
    icu
    fontconfig
    freetype
    libxkbcommon
    libdrm
    libxshmfence
    libunwind
    xkeyboard_config
    systemd
  ];

  dontConfigure = true;
  dontBuild = true;

  unpackPhase = ''
    runHook preUnpack
    rpm2cpio $src | cpio -idmv
    runHook postUnpack
  '';

  installPhase = ''
    runHook preInstall

    # Locate the base directory where Happ is installed
    appBase=$(dirname $(find . -type f -path "*/Happ" -executable | head -n1))
    if [ -z "$appBase" ]; then
        echo "Error: Could not find Happ binary in extracted RPM"
        exit 1
    fi

    appRoot=$(dirname "$appBase")

    mkdir -p $out/opt/happ
    mkdir -p $out/bin
    mkdir -p $out/share/applications
    mkdir -p $out/share/icons
    mkdir -p $out/lib/systemd/system

    cp -r "$appRoot"/* $out/opt/happ/

    # Symlink auxiliary binaries into $out/bin
    for bin in happ-tcping happd; do
      if [ -f "$out/opt/happ/bin/$bin" ]; then
        ln -s "$out/opt/happ/bin/$bin" "$out/bin/$bin"
      fi
    done

    # Symlink subdirectory executables (antifilter, tun2proxy, etc.)
    for sub in antifilter tun tun2 core; do
      if [ -d "$out/opt/happ/bin/$sub" ]; then
        for exe in "$out/opt/happ/bin/$sub"/*; do
          if [ -f "$exe" ] && [ -x "$exe" ]; then
            ln -s "$exe" "$out/bin/$(basename "$exe")"
          fi
        done
      fi
    done

    # Desktop and icon files
    if [ -d "usr/share/applications" ]; then
      cp -r usr/share/applications/* $out/share/applications/
    fi
    if [ -d "usr/share/icons" ]; then
      cp -r usr/share/icons/* $out/share/icons/
    fi
    if [ -d "usr/share/mime" ]; then
      cp -r usr/share/mime/* $out/share/mime/
    fi

    # Systemd service
    if [ -f "usr/lib/systemd/system/happd.service" ]; then
      cp usr/lib/systemd/system/happd.service $out/lib/systemd/system/
    elif [ -f "lib/systemd/system/happd.service" ]; then
      cp lib/systemd/system/happd.service $out/lib/systemd/system/
    fi

    find $out/opt/happ/bin -type f -exec chmod +x {} \;

    runHook postInstall
  '';

  dontWrapQtApps = true;

  appendRunpaths = [
    "${placeholder "out"}/opt/happ/lib"
  ];

  autoPatchelfIgnoreMissingDeps = [
    "libtun2proxy.so"
    "libQt6Core.so.6"
    "libQt6Gui.so.6"
    "libQt6Widgets.so.6"
    "libQt6Qml.so.6"
    "libQt6Quick.so.6"
    "libQt6WlShellIntegration.so.6"
    "libQt6WaylandClient.so.6"
  ];

  postFixup = ''
    # Find the real binary (follow symlinks)
    realBin=$(readlink -f $out/opt/happ/bin/Happ)
    if [ ! -x "$realBin" ]; then
        echo "Error: Cannot find executable Happ binary" >&2
        exit 1
    fi

    # Create wrapper script in bin directory
    makeWrapper "$realBin" "$out/bin/happ"\
      --set QT_QUICK_BACKEND "software" \
      --set QT_PLUGIN_PATH "$out/opt/happ/lib/plugins" \
      --set QML2_IMPORT_PATH "$out/opt/happ/lib/qml" \
      --set QTWEBENGINE_RESOURCES_PATH "$out/opt/happ/resources" \
      --set XKB_CONFIG_ROOT "${xkeyboard_config}/share/X11/xkb" \
      --prefix LD_LIBRARY_PATH : "$out/opt/happ/lib"

    # Symlink uppercase Happ to the wrapper
    ln -sf $out/bin/happ $out/bin/Happ
  '';

  meta = with lib; {
    description = "Happ proxy utility . a modern VPN/proxy client";
    homepage = "https://github.com/Happ-proxy/happ-desktop";
    license = licenses.unfree;
    platforms = platforms.linux;
    maintainers = with maintainers; [ "JаiledFish" ];
  };
}