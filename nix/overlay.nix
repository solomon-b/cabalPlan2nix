final: prev: {
  haskell = prev.haskell // {
    lib = prev.haskell.lib // {
      cabalPlan2nix = final.callPackage ./build-support/cabalPlan2nix { };
    };
  };
}
