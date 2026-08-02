{pkgs ? import <nixpkgs> {}}: let
  lock = builtins.fromJSON (builtins.readFile ./flake.lock);

  # Fetch git input from lockfile
  fetchInput = nodeName: let
    node = lock.nodes.${nodeName}.locked;
  in
    if node.type or "" == "github"
    then
      pkgs.fetchFromGitHub {
        owner = node.owner;
        repo = node.repo;
        rev = node.rev;
        hash = node.narHash;
      }
    else
      pkgs.fetchgit {
        url = node.url;
        rev = node.rev;
        hash = node.narHash;
      };

  waywallen-src = fetchInput "waywallen-src";
  waywallen-display-src = fetchInput "waywallen-display-src";
  open-wallpaper-engine-src = fetchInput "open-wallpaper-engine-src";

  # Clang 22 + older libstdc++ (conda sysroot_linux-64=2.28 baseline).
  llvmPackages = pkgs.callPackage ./pkgs/upstream-clang.nix {};

  fetchDep = pkgs.callPackage ./pkgs/fetch-upstream-deps.nix {
    depsJson = builtins.fromJSON (builtins.readFile "${waywallen-src}/deps.json");
    lfsHashes.qml_material = "sha256-bAr2BiW7Rj3QBFIOCHyIKBuXxZiHjFz7U7pOAbPzhrA=";
  };

  waywallen-daemon = pkgs.callPackage ./pkgs/waywallen-daemon.nix {src = waywallen-src;};
  waywallen-ui = pkgs.callPackage ./pkgs/waywallen-ui.nix {
    inherit llvmPackages;
    src = waywallen-src;
    rstd-src = fetchDep "rstd";
    ncrequest-src = fetchDep "ncrequest";
    wavsen-src = fetchDep "wavsen";
    qml_material-src = fetchDep "qml_material";
    QExtra-src = fetchDep "QExtra";
    pegtl-src = fetchDep "pegtl";
  };
  waywallen-plugins = pkgs.callPackage ./pkgs/waywallen-plugins.nix {
    inherit llvmPackages;
    src = waywallen-src;
    rstd-src = fetchDep "rstd";
    wavsen-src = fetchDep "wavsen";
  };
  waywallen-layer-shell = pkgs.callPackage ./pkgs/waywallen-layer-shell.nix {src = waywallen-display-src;};
  waywallen-kde = pkgs.callPackage ./pkgs/waywallen-kde.nix {src = waywallen-display-src;};
  waywallen-gnome = pkgs.callPackage ./pkgs/waywallen-gnome.nix {src = waywallen-display-src;};
in rec {
  inherit waywallen-daemon waywallen-ui waywallen-plugins waywallen-layer-shell waywallen-kde waywallen-gnome;

  waywallen-open-wallpaper-engine = pkgs.callPackage ./pkgs/waywallen-open-wallpaper-engine.nix {
    inherit llvmPackages waywallen-plugins;
    src = open-wallpaper-engine-src;
    vma-src = fetchDep "vma";
    vvk-src = fetchDep "vvk";
  };

  # Combined package: daemon + plugins + open wallpaper engine + ui
  waywallen = pkgs.symlinkJoin {
    name = "waywallen-${waywallen-daemon.version}";
    paths = [waywallen-daemon waywallen-plugins waywallen-open-wallpaper-engine waywallen-ui];
    nativeBuildInputs = [pkgs.makeWrapper];
    postBuild = ''
      wrapProgram $out/bin/waywallen \
        --add-flags "--ui $out/bin/waywallen-ui --plugin $out/share/waywallen"
    '';
  };
}
