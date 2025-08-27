# cabalPlan2nix

*WORK IN PROGRESS*

Generate Nix derivations from Cabal `plan.json` files.

`cabalPlan2nix` is a Nix tool that converts Cabal's `plan.json` files into Nixpkgs-compatible Haskell package sets.

## Quick Start

### Flake Input

Add to your `flake.nix`:

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    cabalPlan2nix.url = "github:solomon-b/cabalPlan2nix";
  };

  outputs = { self, nixpkgs, cabalPlan2nix }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};

      # Generate the Haskell package set from the example's plan.json
      examplePlan = pkgsWithOverlay.haskell.lib.cabalPlan2nix ./path/to/plan.json "base/path/prefix/from/plan/file";

      # Generate package set from your plan.json
      haskellPackages = pkgs.haskell.packages.ghc98.extend examplePlan.overlay;

    in {
      # Use myPackages overlay with your Haskell package set
      packages.${system}.default = haskellPackages.myPackage;
    };
}
```

### Direct Import

```nix
let
  pkgs = import <nixpkgs> { overlays = [ (import /path/to/cabalPlan2nix/nix/overlay.nix) ]; };
  examplePlan = pkgs.haskell.lib.cabalPlan2nix ./plan.json;
  haskellPackages = pkgs.haskell.packages.ghc98.extend examplePlan.overlay;
in
  haskellPackages.myPackage
```

## Generating plan.json

Generate a `plan.json` file using Cabal:

```bash
cabal build --dry-run ; cp dist-newstyle/cache/plan.json .
```

This creates a `plan.json` file in `dist-newstyle/cache/` that contains the complete build plan computed by Cabal's dependency solver.

## License

BSD-3
