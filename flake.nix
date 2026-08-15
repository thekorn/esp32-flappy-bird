{
  description = "ESP32-S3 experiments with ESP-IDF and Zig";

  inputs.esp-dev.url = "github:mirrexagon/nixpkgs-esp-dev";

  outputs = { esp-dev, ... }:
    let
      supportedSystems = [
        "x86_64-linux"
        "aarch64-linux"
        "aarch64-darwin"
      ];

      forAllSystems = function:
        builtins.listToAttrs (map
          (system: {
            name = system;
            value = function system;
          })
          supportedSystems);

      zigSources = {
        x86_64-linux = {
          url = "https://github.com/kassane/zig-espressif-bootstrap/releases/download/0.17.0-xtensa-dev/zig-relsafe-x86_64-linux-musl-baseline.tar.xz";
          hash = "sha256-5EaQJ74LDdar6oFfBc/ZZ49Kh+n3KGh1CokZA3G9iPI=";
        };
        aarch64-linux = {
          url = "https://github.com/kassane/zig-espressif-bootstrap/releases/download/0.17.0-xtensa-dev/zig-relsafe-aarch64-linux-musl-baseline.tar.xz";
          hash = "sha256-6mbHxfTfqHcsd2d7ZzIm4nZ4jYnScHjaBAeTZW7tsnQ=";
        };
        aarch64-darwin = {
          url = "https://github.com/kassane/zig-espressif-bootstrap/releases/download/0.17.0-xtensa-dev/zig-relsafe-aarch64-macos-baseline.tar.xz";
          hash = "sha256-NncNcPDankC6Z/2G8f6CjECSm12WN0dkG+nVq8iie3A=";
        };
      };
    in
    {
      devShells = forAllSystems (system:
        let
          pkgs = esp-dev.inputs.nixpkgs.legacyPackages.${system};
          esp-idf = esp-dev.packages.${system}.esp-idf-xtensa.overrideAttrs (old: {
            # Building the immutable IDF checkout creates a synthetic Git
            # commit. Host-wide signing settings must not affect that build.
            installPhase = ''
              export GIT_CONFIG_NOSYSTEM=1
            '' + old.installPhase;
          });
          zig-xtensa = pkgs.stdenv.mkDerivation {
            pname = "zig-xtensa";
            version = "0.17.0-xtensa";
            src = pkgs.fetchurl zigSources.${system};

            dontConfigure = true;
            dontBuild = true;
            dontFixup = true;

            installPhase = ''
              runHook preInstall
              mkdir -p "$out/bin" "$out/lib" "$out/doc"
              cp zig "$out/bin/"
              cp -r lib/. "$out/lib/"
              cp -r doc/. "$out/doc/"
              runHook postInstall
            '';
          };
          lvgl-source = pkgs.fetchzip {
            url = "https://github.com/lvgl/lvgl/archive/refs/tags/v8.4.0.tar.gz";
            hash = "sha256-9IrcWUUsem3so8trM+0odNWpuqVEdtkqXOfJsV9kFFM=";
          };
        in
        {
          default = pkgs.mkShell {
            packages = [
              esp-idf
              zig-xtensa
              pkgs.SDL2
            ];
            LVGL_SOURCE_DIR = lvgl-source;
            shellHook = ''
              echo "ESP32-S3 environment: ESP-IDF $(idf.py --version | sed 's/^ESP-IDF //'), Zig $(zig version)"
            '';
          };
        });
    };
}
