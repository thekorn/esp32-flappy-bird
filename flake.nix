{
  description = "ESP32-S3 experiments with ESP-IDF";

  inputs.esp-dev.url = "github:mirrexagon/nixpkgs-esp-dev";

  outputs = { esp-dev, ... }:
    let
      supportedSystems = [
        "x86_64-linux"
        "aarch64-linux"
      ];

      forAllSystems = function:
        builtins.listToAttrs (map
          (system: {
            name = system;
            value = function system;
          })
          supportedSystems);

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
        in
        {
          default = pkgs.mkShell {
            packages = [
              esp-idf
            ];
            shellHook = ''
              echo "ESP32-S3 environment: ESP-IDF $(idf.py --version | sed 's/^ESP-IDF //')"
            '';
          };
        });
    };
}
