{ lib
, rustPlatform
, pkg-config
, protobuf
, sqlite
, libGL
, vulkan-loader
, wayland
, libgbm
, libxkbcommon
, makeWrapper
, src
}:

rustPlatform.buildRustPackage rec {
  pname = "waywallen-daemon";
  version = "0.2.6";

  inherit src;

  cargoHash = "sha256-jBZX5x/pIgy1IPuP6cbWaWtpKuUU7be8gwZSZLmCjkE=";

  nativeBuildInputs = [
    pkg-config
    protobuf
    makeWrapper
  ];

  buildInputs = [
    sqlite
    libGL
    vulkan-loader
    wayland
    libgbm
    libxkbcommon
  ];

  cargoBuildFlags = [ "-p" "waywallen" ];
  doCheck = false;

  postInstall = ''
    wrapProgram $out/bin/waywallen \
      --prefix LD_LIBRARY_PATH : ${lib.makeLibraryPath [ libGL vulkan-loader wayland libgbm libxkbcommon ]}
    wrapProgram $out/bin/waywallen_renderer \
      --prefix LD_LIBRARY_PATH : ${lib.makeLibraryPath [ libGL vulkan-loader wayland libgbm libxkbcommon ]}
  '';

  meta = with lib; {
    description = "Rust daemon component of waywallen";
    homepage = "https://github.com/waywallen/waywallen";
    license = licenses.mit;
    platforms = platforms.linux;
  };
}
