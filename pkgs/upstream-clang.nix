# Toolchain matching upstream environment.yml / BUILD.md:
#   clang=22, clang-tools=22, lld=22
#   sysroot_linux-64=2.28 (manylinux_2_28) → older libstdc++ headers than
#   nixpkgs' default gcc 15
#
# Compile against gcc13's libstdc++ headers so C++20 modules + the deps.json
# rstd pin behave like the conda manylinux baseline. Link/run against the
# default gcc's libstdc++ so we remain ABI-compatible with nixpkgs C++ libs
# (e.g. libsrt needs CXXABI_1.3.15).
{
  lib,
  llvmPackages_22,
  gcc13,
  gcc,
  overrideCC,
}: let
  clang = llvmPackages_22.clang.override {
    gccForLibs = gcc13.cc;
  };
  stdenv = overrideCC llvmPackages_22.stdenv clang;
  libstdcxx = lib.getLib gcc.cc;
  # NIX_LDFLAGS is passed to ld directly (no -Wl, prefix).
  libstdcxxLinkFlags = [
    "-L${libstdcxx}/lib"
    "-rpath"
    "${libstdcxx}/lib"
  ];
in
  llvmPackages_22
  // {
    inherit stdenv clang libstdcxx libstdcxxLinkFlags;
  }
