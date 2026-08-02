{
  lib,
  llvmPackages, # upstream clang 22 + manylinux-compatible libstdc++ (see upstream-clang.nix)
  cmake,
  pkg-config,
  ffmpeg,
  libGL, # EGL headers (via libGL/mesa)
  libgbm, # gbm.pc (mesa-libgbm)
  vulkan-loader,
  vulkan-headers,
  libva,
  libpulseaudio,
  glslang, # provides glslangValidator, required by wavsen::video
  ninja,
  src,
  rstd-src,
  wavsen-src,
}:
llvmPackages.stdenv.mkDerivation rec {
  pname = "waywallen-plugins";
  version = "0.2.6";

  inherit src;

  hardeningDisable = ["fortify"];

  postPatch = ''
    # Patch top-level CMakeLists.txt:
    #   - Remove the CPackConfig include (unneeded, may pull in cpack)
    substituteInPlace CMakeLists.txt \
      --replace "include(CPackConfig)" "# include(CPackConfig)"

    # Filter out AMD DCC modifiers (vendor ID 0x02, DCC bit 13) from Vulkan format caps:
    substituteInPlace bridge/src/pool_vulkan.c \
      --replace-fail '            if ((ff & want_features) != want_features) continue;' '            if ((ff & want_features) != want_features) continue;
            if (((probed[i].drmFormatModifier >> 56) == 2) && ((probed[i].drmFormatModifier >> 13) & 1)) continue;'
  '';

  nativeBuildInputs = [
    cmake
    pkg-config
    ninja
    glslang # glslangValidator for wavsen shader compilation
    llvmPackages.clang-tools
    llvmPackages.lld
  ];

  buildInputs = [
    ffmpeg
    libGL # EGL headers
    libgbm # GBM (gbm.pc + libgbm)
    vulkan-loader
    vulkan-headers
    libva # wavsen dependency
    libpulseaudio # wavsen dependency
    llvmPackages.libstdcxx # newer libstdc++ for linking nixpkgs C++ deps
  ];

  # Prefer default-gcc libstdc++ at link time (compile still uses gcc13 headers).
  NIX_LDFLAGS = llvmPackages.libstdcxxLinkFlags;
  cmakeFlags = [
    # Only build the plugins component
    "-DWAYWALLEN_BUILD_DAEMON=OFF"
    "-DWAYWALLEN_BUILD_UI=OFF"
    "-DWAYWALLEN_BUILD_PLUGINS=ON"
    # MPV plugin requires libmpv — skip for now
    "-DWAYWALLEN_BUILD_MPV_PLUGIN=OFF"
    # Point FetchDeps at the pre-fetched Nix store paths
    "-DFETCHDEPS_LOCAL_rstd=${rstd-src}"
    "-DFETCHDEPS_LOCAL_wavsen=${wavsen-src}"
    # C++20 module scanning
    "-DCMAKE_CXX_COMPILER_CLANG_SCAN_DEPS=${llvmPackages.clang-tools}/bin/clang-scan-deps"
  ];

  meta = with lib; {
    description = "Renderer plugin binaries (image + video) for waywallen";
    homepage = "https://github.com/waywallen/waywallen";
    license = licenses.mit;
    platforms = platforms.linux;
  };
}
