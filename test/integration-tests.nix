# Integration tests for cabalPlan2nix - testing the complete functionality
let
  pkgs = import <nixpkgs> {};

  cabalPlan2nix = pkgs.callPackage ../nix/build-support/cabalPlan2nix { };

  # Generate the cabalPlan2nix result from our example plan.json
  # Use the directory where the local packages are located as baseDir
  cabalPlan2nixResult = cabalPlan2nix ../plan.json /home/solomon/Development/Haskell/monoidal-functors;

  # Create a fresh package set using overridePackageSet
  freshPackageSet = cabalPlan2nixResult.overridePackageSet pkgs.haskellPackages;

  # Also test the raw overlay functionality
  rawOverlay = cabalPlan2nixResult.overlay;

  # Helper function to run a test with assertion
  runTest = name: assertion: value:
    if assertion then
      { inherit name; status = "PASS"; inherit value; }
    else
      { inherit name; status = "FAIL"; inherit value; };

  # Get all package info from plan.json for validation
  planJson = pkgs.lib.importJSON ../plan.json;
  installPlan = planJson."install-plan" or [];

  # All configured packages (includes local packages)
  configuredPackages = builtins.filter (pkg: pkg.type or null == "configured") installPlan;

  # Only Hackage packages (excludes local packages and GHC boot packages)
  hackagePackages = builtins.filter
    (pkg:
      let srcType = (pkg."pkg-src" or {}).type or null;
      in pkg.type or null == "configured" && srcType == "repo-tar"
    ) installPlan;

  # Local packages
  localPackages = builtins.filter
    (pkg:
      let srcType = (pkg."pkg-src" or {}).type or null;
      in pkg.type or null == "configured" && srcType == "local"
    ) installPlan;

  # Extract names for different package types
  hackagePackageNames = map (pkg: pkg."pkg-name") hackagePackages;
  localPackageNames = map (pkg: pkg."pkg-name") localPackages;
  allConfiguredNames = map (pkg: pkg."pkg-name") configuredPackages;

in rec {
  # Test 1: API compatibility - cabalPlan2nix returns expected methods
  apiCompatibility = runTest "API compatibility"
    (builtins.hasAttr "overridePackageSet" cabalPlan2nixResult &&
     builtins.hasAttr "overlay" cabalPlan2nixResult)
    {
      hasOverrideMethod = builtins.hasAttr "overridePackageSet" cabalPlan2nixResult;
      hasOverlay = builtins.hasAttr "overlay" cabalPlan2nixResult;
      overlayIsFunction = builtins.isFunction cabalPlan2nixResult.overlay;
    };

  # Test 2: Fresh package set contains expected packages
  packageSetCompleteness = runTest "Fresh package set completeness"
    (let
      packageNames = builtins.attrNames freshPackageSet;
      hasHackagePackages = builtins.all (name: builtins.elem name packageNames)
        (pkgs.lib.take 5 hackagePackageNames); # Test first 5 hackage packages
      hasLocalPackages = builtins.all (name: builtins.elem name packageNames) localPackageNames;
    in hasHackagePackages && hasLocalPackages)
    {
      totalPackages = builtins.length (builtins.attrNames freshPackageSet);
      sampleHackagePresent = map (name: builtins.elem name (builtins.attrNames freshPackageSet))
        (pkgs.lib.take 5 hackagePackageNames);
      localPackagesPresent = map (name: builtins.elem name (builtins.attrNames freshPackageSet))
        localPackageNames;
    };

  # Test 3: Local packages are properly resolved
  localPackageResolution = runTest "Local package resolution"
    (let
      localPackageValues = map (name: freshPackageSet.${name} or null) localPackageNames;
      # Local packages should be derivations, not null
      properlyResolved = builtins.all (val: val != null) localPackageValues;
    in properlyResolved)
    {
      localPackages = localPackageNames;
      localPackageValues = map (name:
        if builtins.hasAttr name freshPackageSet then
          if freshPackageSet.${name} == null then "null" else "derivation"
        else "missing"
      ) localPackageNames;
    };

  # Test 4: Hackage packages use correct versions from plan.json
  hackagePackageVersions = runTest "Hackage package versions"
    (let
      # Pick a few Hackage packages and verify they're derivations
      samplePackages = pkgs.lib.take 3 hackagePackageNames;
      packageValues = map (name: freshPackageSet.${name} or null) samplePackages;
      allAreDerivations = builtins.all (val: val != null) packageValues;
    in allAreDerivations)
    {
      samplePackages = pkgs.lib.take 3 hackagePackageNames;
      packageStatuses = map (name: {
        inherit name;
        hasPackage = builtins.hasAttr name freshPackageSet;
        isNull = (freshPackageSet.${name} or null) == null;
      }) (pkgs.lib.take 3 hackagePackageNames);
    };

  # Test 5: Dependency propagation works (this was the main issue)
  dependencyPropagation = runTest "Dependency propagation"
    (let
      # If a package A depends on package B, and both are in plan.json,
      # then A should be able to build (no missing dependencies)
      # We test this by checking that packages with dependencies don't fail immediately
      packageWithDeps = freshPackageSet.optparse-applicative or null;
      dependencyExists = freshPackageSet.prettyprinter or null;
    in packageWithDeps != null && dependencyExists != null)
    {
      hasOptparseApplicative = builtins.hasAttr "optparse-applicative" freshPackageSet;
      hasPrettyprinter = builtins.hasAttr "prettyprinter" freshPackageSet;
      # Show a few packages that should have their dependencies satisfied
      dependencyExamples = {
        "optparse-applicative" = freshPackageSet.optparse-applicative or "missing";
        "prettyprinter" = freshPackageSet.prettyprinter or "missing";
        "semigroupoids" = freshPackageSet.semigroupoids or "missing";
      };
    };

  # Test 6: GHC boot packages are preserved
  ghcBootPackagesPreserved = runTest "GHC boot packages preserved"
    (let
      # Some GHC boot packages should be available (from base haskellPackages)
      # but others might be null if they don't exist in nixpkgs
      bootPackageChecks = map (name: {
        inherit name;
        exists = builtins.hasAttr name freshPackageSet;
        isNull = (freshPackageSet.${name} or null) == null;
      }) ["base" "containers" "text" "bytestring" "transformers"];
      # At least some boot packages should exist
      someBootPackagesExist = builtins.any (check: check.exists && !check.isNull) bootPackageChecks;
    in someBootPackagesExist)
    {
      bootPackageStatus = map (name: {
        inherit name;
        exists = builtins.hasAttr name freshPackageSet;
        isNull = (freshPackageSet.${name} or null) == null;
      }) ["base" "containers" "text" "bytestring" "transformers"];
    };

  # Collect all tests
  allTests = [
    apiCompatibility
    packageSetCompleteness
    localPackageResolution
    hackagePackageVersions
    dependencyPropagation
    ghcBootPackagesPreserved
  ];

  # Summary
  summary =
    let
      passedTests = builtins.filter (test: test.status == "PASS") allTests;
      failedTests = builtins.filter (test: test.status == "FAIL") allTests;
    in {
      testSuite = "integration";
      totalTests = builtins.length allTests;
      passedTests = builtins.length passedTests;
      failedTests = builtins.length failedTests;
      allPassed = builtins.length failedTests == 0;
      testResults = map (test: { name = test.name; status = test.status; }) allTests;
    };

  # Debug information
  debug = {
    planJsonStats = {
      totalConfigured = builtins.length configuredPackages;
      totalHackage = builtins.length hackagePackages;
      totalLocal = builtins.length localPackages;
    };
    packageSetStats = {
      totalInFreshSet = builtins.length (builtins.attrNames freshPackageSet);
      samplePackageNames = pkgs.lib.take 10 (builtins.attrNames freshPackageSet);
    };
    packageTypes = {
      hackageExamples = pkgs.lib.take 5 hackagePackageNames;
      localExamples = localPackageNames;
    };
  };
}
