{
  description = "wrapper for https://github.com/deref/exo";

  # Nixpkgs / NixOS version to use.
  inputs.nixpkgs.url = "nixpkgs/nixos-unstable";

  inputs.flake-compat = {
    url = "github:edolstra/flake-compat";
    flake = false;
  };

  outputs =
    { self, nixpkgs, ... }:
    let
      # Generate a user-friendly version number.
      version = builtins.substring 2021 11 self.lastModifiedDate;
      # System types to support.
      supportedSystems = [
        "x86_64-linux"
        "aarch64-linux"
      ];
      # Helper function to generate an attrset '{ x86_64-linux = f "x86_64-linux"; ... }'.
      forAllSystems = nixpkgs.lib.genAttrs supportedSystems;
      # Nixpkgs instantiated for supported system types.
      nixpkgsFor = forAllSystems (system: import nixpkgs { inherit system; });
    in
    {
      # Provide some binary packages for selected system types.
      packages = forAllSystems (system: {
        exo = nixpkgsFor.${system}.stdenvNoCC.mkDerivation {
          pname = "exo";
          inherit version;
          src = nixpkgs.lib.cleanSourceWith {
            filter = name: type: type != "regular" || !nixpkgs.lib.hasSuffix ".nix" name;
            src = nixpkgs.lib.cleanSource ./.;
          };
          dontConfigure = true;
          dontBuild = true;
          installPhase = ''
            runHook preInstall

            mkdir -p $out/bin
            ${nixpkgsFor.${system}.gnutar}/bin/tar -zxf \
              exo_standalone_2021.11.16_linux_amd64.tar.gz
            mv ./exo $out/bin

            runHook postInstall
          '';
        };
      });

      # The default package for 'nix build'. This makes sense if the
      # flake provides only one package or there is a clear "main"
      # package.
      defaultPackage = forAllSystems (system: self.packages.${system}.exo);

      devShell = forAllSystems (
        system:
        let
          pkgs = nixpkgsFor.${system};
        in
        pkgs.mkShell { buildInputs = with pkgs; [ gnutar ]; }
      );
    };
}
