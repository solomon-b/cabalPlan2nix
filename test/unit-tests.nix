# Unit tests for individual helper functions
let
  pkgs = import <nixpkgs> {};
  helpers = import ../nix/build-support/cabalPlan2nix/helpers.nix { lib = pkgs.lib; };
  inherit (helpers) makeRelativePath;

  # Test runner helper
  runTest = name: expected: actual:
    let
      passed = expected == actual;
    in {
      inherit name expected actual passed;
      status = if passed then "PASS" else "FAIL";
    };

in rec {
  # Tests for makeRelativePath function
  makeRelativePathTests = {
    # Test 1: Basic relative path conversion
    basicRelativePath = runTest "Basic relative path" 
      "subdir/file.txt"
      (makeRelativePath "/home/user/project" "/home/user/project/subdir/file.txt");

    # Test 2: Same directory (should return "./")  
    sameDirectory = runTest "Same directory"
      "./"
      (makeRelativePath "/home/user/project" "/home/user/project");

    # Test 3: Same directory with trailing dot
    sameDirWithDot = runTest "Same directory with dot"
      "./"
      (makeRelativePath "/home/user/project" "/home/user/project/.");

    # Test 4: Path not under base directory (should return as-is)
    pathNotUnderBase = runTest "Path not under base"
      "/different/path/file.txt"
      (makeRelativePath "/home/user/project" "/different/path/file.txt");

    # Test 5: Nested subdirectories
    nestedSubdirs = runTest "Nested subdirectories"
      "src/main/haskell/MyModule.hs" 
      (makeRelativePath "/home/user/project" "/home/user/project/src/main/haskell/MyModule.hs");

    # Test 6: Root to root (edge case)
    rootToRoot = runTest "Root to root"
      "./"
      (makeRelativePath "/" "/");

    # Test 7: Base dir with trailing slash
    baseDirTrailingSlash = runTest "Base dir with trailing slash"
      "file.txt"
      (makeRelativePath "/home/user/project/" "/home/user/project/file.txt");

    # Test 8: Empty relative path after base removal
    emptyPath = runTest "Empty path becomes current dir"
      "./"
      (makeRelativePath "/home/user/project" "/home/user/project/");

    # Test 9: Path type conversion (should handle path types)
    pathTypeConversion = runTest "Path type conversion" 
      "subdir"
      (makeRelativePath /home/user/project /home/user/project/subdir);

    # Test 10: Similar but not matching base path
    similarButDifferentBase = runTest "Similar but different base"
      "/home/user/project2/file.txt"
      (makeRelativePath "/home/user/project" "/home/user/project2/file.txt");
  };

  # Collect all makeRelativePath tests
  allMakeRelativePathTests = builtins.attrValues makeRelativePathTests;

  # Summary for makeRelativePath tests
  makeRelativePathSummary = 
    let
      passedTests = builtins.filter (test: test.passed) allMakeRelativePathTests;
      failedTests = builtins.filter (test: !test.passed) allMakeRelativePathTests;
    in {
      testSuite = "makeRelativePath";
      totalTests = builtins.length allMakeRelativePathTests;
      passedTests = builtins.length passedTests;
      failedTests = builtins.length failedTests;
      allPassed = builtins.length failedTests == 0;
      results = map (test: { 
        name = test.name; 
        status = test.status;
        expected = test.expected;
        actual = test.actual;
      }) allMakeRelativePathTests;
    };

  # Overall unit test summary
  summary = {
    testSuites = {
      makeRelativePath = makeRelativePathSummary;
    };
    totalSuites = 1;
    allSuitesPass = makeRelativePathSummary.allPassed;
  };
}