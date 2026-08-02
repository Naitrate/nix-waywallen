# Fetch a named dependency from an upstream flatpak-style deps.json.
#
# Supported entry types:
#   - git:     builtins.fetchGit at the pinned commit (or pkgs.fetchgit + LFS
#              when `lfsHashes.<name>` is set)
#   - archive: pkgs.fetchurl using the sha256/sha512 from deps.json, unpacked
#              into a store path (same layout FETCHDEPS_LOCAL expects)
#   - file:    same as archive but DOWNLOAD_NO_EXTRACT — left as fetchurl path
#
# Entries with `only-arches` are filtered to the current host platform.
#
# Usage:
#   fetchDep = pkgs.callPackage ./fetch-upstream-deps.nix {
#     depsJson = builtins.fromJSON (builtins.readFile "${src}/deps.json");
#     lfsHashes.qml_material = "sha256-...";
#   };
#   rstd-src = fetchDep "rstd";
{
  lib,
  pkgs,
  stdenvNoCC,
  fetchurl,
  fetchgit,
  depsJson,
  # Optional: attrset of dep name -> SRI/base32 hash for git+LFS fetches.
  lfsHashes ? {},
}: let
  system = pkgs.stdenv.hostPlatform.system;
  flatpakArch =
    if system == "x86_64-linux"
    then "x86_64"
    else if system == "aarch64-linux"
    then "aarch64"
    else throw "fetch-upstream-deps: unsupported system ${system}";

  matchesArch = dep: let
    arches = dep."only-arches" or null;
  in
    arches == null || builtins.elem flatpakArch arches;

  entriesNamed = name:
    builtins.filter (
      d: (d.x-cmake.name or "") == name && matchesArch d
    )
    depsJson;

  archiveFetchArgs = dep: let
    name = dep.x-cmake.name;
    # Keep a recognizable archive suffix so unpackPhase can detect the format.
    # Prefer dest-filename from deps.json; otherwise derive from the URL.
    urlBase = baseNameOf dep.url;
    fileName =
      dep."dest-filename"
      or (
        if builtins.match ".*\\.(tar\\.gz|tar\\.bz2|tar\\.xz|tgz|zip|tar)" urlBase != null
        then urlBase
        else "${name}-src.tar.gz"
      );
  in
    {
      url = dep.url;
      name = fileName;
    }
    // (
      if dep ? sha256
      then {sha256 = dep.sha256;}
      else if dep ? sha512
      then {sha512 = dep.sha512;}
      else if dep ? sha1
      then {sha1 = dep.sha1;}
      else if dep ? md5
      then {md5 = dep.md5;}
      else throw "fetch-upstream-deps: archive '${name}' has no sha256/sha512/sha1/md5"
    );

  fetchArchive = dep: let
    name = dep.x-cmake.name;
  in
    stdenvNoCC.mkDerivation {
      pname = "upstream-${name}";
      version = "vendor";
      src = fetchurl (archiveFetchArgs dep);
      dontConfigure = true;
      dontBuild = true;
      preferLocalBuild = true;
      allowSubstitutes = true;
      installPhase = ''
        runHook preInstall
        mkdir -p "$out"
        # unpackPhase already extracted (and entered a single top-level dir).
        cp -a . "$out/"
        runHook postInstall
      '';
    };

  fetchGitDep = dep: let
    name = dep.x-cmake.name;
    rev =
      dep.commit
      or dep.tag
      or (throw "fetch-upstream-deps: git '${name}' needs commit or tag");
  in
    if lfsHashes ? ${name}
    then
      fetchgit {
        url = dep.url;
        inherit rev;
        hash = lfsHashes.${name};
        fetchLFS = true;
      }
    else
      builtins.fetchGit {
        url = dep.url;
        inherit rev;
        allRefs = true;
      };

  fetchOne = dep: let
    dtype = dep.type;
  in
    if dtype == "git"
    then fetchGitDep dep
    else if dtype == "archive"
    then fetchArchive dep
    else if dtype == "file"
    then fetchurl (archiveFetchArgs dep)
    else throw "fetch-upstream-deps: unsupported type '${dtype}' for ${dep.x-cmake.name}";
in
  name: let
    matches = entriesNamed name;
  in
    if matches == []
    then throw "fetch-upstream-deps: '${name}' not found in deps.json (arch=${flatpakArch})"
    else fetchOne (builtins.head matches)
