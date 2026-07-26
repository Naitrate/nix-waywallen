# Toolchain matching upstream environment.yml / BUILD.md:
#   clang=22, clang-tools=22, lld=22
#   sysroot_linux-64=2.28 (manylinux_2_28) → older libstdc++ than nixpkgs' default gcc 15
#
# Keep LLVM 22 for the compiler/modules support upstream requires, but point
# clang at gcc14's libstdc++ so C++20 module builds match the conda-forge
# baseline while remaining ABI-compatible with nixpkgs C++ libraries
# (need CXXABI_1.3.15 for e.g. libsrt from ffmpeg).
{
  llvmPackages_22,
  gcc14,
  overrideCC,
}: let
  clang = llvmPackages_22.clang.override {
    gccForLibs = gcc14.cc;
  };
  stdenv = overrideCC llvmPackages_22.stdenv clang;
in
  llvmPackages_22
  // {
    inherit stdenv clang;
  }
