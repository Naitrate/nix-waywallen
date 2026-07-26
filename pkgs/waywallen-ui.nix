{ lib
, llvmPackages # upstream clang 22 + manylinux-compatible libstdc++ (see upstream-clang.nix)
, cmake
, pkg-config
, qt6
, protobuf
, curl
, ffmpeg
, asio
, libva
, libpulseaudio
, glslang
, vulkan-loader
, ninja
, src
, rstd-src
, ncrequest-src
, wavsen-src
, qml_material-src
, QExtra-src
, asio-src
, pegtl-src
}:
llvmPackages.stdenv.mkDerivation rec {
  pname = "waywallen-ui";
  version = "0.2.5";

  inherit src;

  postUnpack = ''
    sourceRoot="$sourceRoot/ui"
  '';

  hardeningDisable = [ "fortify" ];

  postPatch = ''
    substituteInPlace CMakeLists.txt \
      --replace "\''${CMAKE_SOURCE_DIR}/cmake/FetchDeps.cmake" "\''${CMAKE_CURRENT_SOURCE_DIR}/../cmake/FetchDeps.cmake" \
      --replace "fetchdeps(\''${CMAKE_SOURCE_DIR}/deps.json)" "fetchdeps(\''${CMAKE_CURRENT_SOURCE_DIR}/../deps.json NAMES pegtl rstd ncrequest wavsen qml_material QExtra)" \
      --replace "set(QT_QML_GENERATE_QMLLS_INI ON)" "set(QT_QML_GENERATE_QMLLS_INI OFF)"
  '';

  nativeBuildInputs = [
    cmake
    pkg-config
    qt6.wrapQtAppsHook
    qt6.qtgrpc
    protobuf
    glslang
    ninja
    llvmPackages.clang-tools
    llvmPackages.lld
  ];

  buildInputs = [
    qt6.qtbase
    qt6.qtdeclarative
    qt6.qtgrpc
    protobuf
    (curl.override { websocketSupport = true; })
    ffmpeg
    asio
    libva
    libpulseaudio
    qt6.qtwayland
    vulkan-loader
    llvmPackages.libstdcxx
  ];

  NIX_LDFLAGS = llvmPackages.libstdcxxLinkFlags;

  cmakeFlags = [
    "-DFETCHDEPS_LOCAL_rstd=${rstd-src}"
    "-DFETCHDEPS_LOCAL_ncrequest=${ncrequest-src}"
    "-DFETCHDEPS_LOCAL_wavsen=${wavsen-src}"
    "-DFETCHDEPS_LOCAL_qml_material=${qml_material-src}"
    "-DFETCHDEPS_LOCAL_QExtra=${QExtra-src}"
    "-DFETCHDEPS_LOCAL_asio=${asio-src}"
    "-DFETCHDEPS_LOCAL_pegtl=${pegtl-src}"
    "-DCMAKE_MODULE_PATH=${qt6.qtgrpc}/lib/cmake/Qt6"
    "-DCMAKE_CXX_COMPILER_CLANG_SCAN_DEPS=${llvmPackages.clang-tools}/bin/clang-scan-deps"
  ];

  qtWrapperArgs = [
    "--prefix NIXPKGS_QT6_QML_IMPORT_PATH : ${placeholder "out"}/lib/qt6/qml"
    "--prefix QML_IMPORT_PATH : ${placeholder "out"}/lib/qt6/qml"
    "--prefix QML2_IMPORT_PATH : ${placeholder "out"}/lib/qt6/qml"
  ];

  meta = with lib; {
    description = "Qt/QML UI component of waywallen";
    homepage = "https://github.com/waywallen/waywallen";
    license = licenses.mit;
    platforms = platforms.linux;
  };
}
