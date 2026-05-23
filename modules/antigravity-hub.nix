{
  lib,
  stdenv,
  fetchurl,
  asar,
  autoPatchelfHook,
  makeWrapper,
  makeDesktopItem,
  copyDesktopItems,
  alsa-lib,
  at-spi2-atk,
  at-spi2-core,
  atk,
  cairo,
  cups,
  dbus,
  expat,
  glib,
  gtk3,
  libdrm,
  libgbm,
  libglvnd,
  libnotify,
  libsecret,
  libuuid,
  libxkbcommon,
  nspr,
  nss,
  pango,
  systemdLibs,
  udev,
  vulkan-loader,
  libX11,
  libXScrnSaver,
  libXcomposite,
  libXcursor,
  libXdamage,
  libXext,
  libXfixes,
  libXi,
  libXrandr,
  libXrender,
  libXtst,
  libxcb,
  libxshmfence,
  libxkbfile,
  zlib,
}:

let
  pname = "antigravity";
  version = "2.0.1";
  executionId = "6566078776737792";

  runtimeLibs = [
    alsa-lib
    at-spi2-atk
    at-spi2-core
    atk
    cairo
    cups
    dbus
    expat
    glib
    gtk3
    libdrm
    libgbm
    libglvnd
    libnotify
    libsecret
    libuuid
    libxkbcommon
    nspr
    nss
    pango
    stdenv.cc.cc.lib
    systemdLibs
    udev
    vulkan-loader
    libX11
    libXScrnSaver
    libXcomposite
    libXcursor
    libXdamage
    libXext
    libXfixes
    libXi
    libXrandr
    libXrender
    libXtst
    libxcb
    libxshmfence
    libxkbfile
    zlib
  ];

  desktopItem = makeDesktopItem {
    name = "antigravity";
    desktopName = "Antigravity";
    comment = "Agent command center for orchestrating autonomous coding tasks";
    exec = "antigravity %U";
    icon = "antigravity";
    categories = [
      "Development"
      "IDE"
    ];
    startupNotify = true;
    startupWMClass = "Antigravity";
    mimeTypes = [ "x-scheme-handler/antigravity" ];
  };
in
stdenv.mkDerivation {
  inherit pname version;

  src = fetchurl {
    url = "https://storage.googleapis.com/antigravity-public/antigravity-hub/${version}-${executionId}/linux-x64/Antigravity.tar.gz";
    hash = "sha256-Byfh9WlhttI0eUHyeNppzGwX3jvv6YhSSEjNFnOA6as=";
  };

  sourceRoot = "Antigravity-x64";

  nativeBuildInputs = [
    autoPatchelfHook
    asar
    copyDesktopItems
    makeWrapper
  ];

  buildInputs = runtimeLibs;
  runtimeDependencies = runtimeLibs;
  autoPatchelfIgnoreMissingDeps = [
    "libcurl-gnutls.so.4"
    "libcurl.so.4"
    "libffmpeg.so"
  ];

  dontBuild = true;
  dontConfigure = true;
  dontStrip = true;

  desktopItems = [ desktopItem ];

  installPhase = ''
    runHook preInstall

    mkdir -p $out/lib/antigravity $out/bin
    cp -r . $out/lib/antigravity

    makeWrapper $out/lib/antigravity/antigravity $out/bin/antigravity \
      --prefix LD_LIBRARY_PATH : ${lib.makeLibraryPath runtimeLibs}

    mkdir -p $out/share/pixmaps $out/share/icons/hicolor/1024x1024/apps
    asar extract-file $out/lib/antigravity/resources/app.asar icon.png > $out/share/pixmaps/antigravity.png
    cp $out/share/pixmaps/antigravity.png $out/share/icons/hicolor/1024x1024/apps/antigravity.png

    runHook postInstall
  '';

  meta = {
    description = "Standalone agent command center for Google Antigravity 2.0";
    homepage = "https://antigravity.google";
    downloadPage = "https://antigravity.google/download";
    changelog = "https://antigravity.google/changelog";
    license = lib.licenses.unfree;
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
    platforms = [ "x86_64-linux" ];
    mainProgram = "antigravity";
  };
}
