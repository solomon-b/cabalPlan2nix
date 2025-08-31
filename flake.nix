{
  description = "cabalCabalPlan2Nix: Generate Nix derivations from Cabal plan.json files";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    let
      # Define the overlay once at the top level
      overlay = import ./nix/overlay.nix;
    in
    (flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
        # Apply the cabalPlan2nix overlay to get access to the function
        pkgsWithOverlay = pkgs.extend overlay;

        # Generate the Haskell package set from the example's plan.json
        examplePlan = pkgsWithOverlay.haskell.lib.cabalPlan2nix ./example/plan.json "/home/solomon/Development/Nix/cabalPlan2nix/example";

        # Create a Haskell package set with the example's dependencies
        haskellPackages = pkgs.haskell.packages.ghc98.extend examplePlan.overlay;
      in
      {
        packages = {
          example = haskellPackages.example;
          default = self.packages.${system}.example;
        };

        devShells.default = pkgs.mkShell {
          buildInputs = with pkgs; [
            nix
            nixpkgs-fmt
            jq
            cabal-install
            ghc
          ];
        };

        checks = {
          nixpkgs-fmt = pkgs.runCommand "check-nixpkgs-fmt" {} ''
            ${pkgs.nixpkgs-fmt}/bin/nixpkgs-fmt --check ${./.}
            touch $out
          '';
        };
      })) // {
      overlays.default = overlay;
    };
}
