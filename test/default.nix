# Main test entrypoint - runs all test suites and provides unified results
#
# nix eval -f test/ summary.overall
let
  # Import all test suites
  unitTests = import ./unit-tests.nix;
  integrationTests = import ./integration-tests.nix;

  # Combine results from all test suites
  allTestSuites = {
    unit = unitTests.summary;
    integration = integrationTests.summary;
  };

  # Calculate overall statistics
  totalTests = unitTests.summary.testSuites.makeRelativePath.totalTests + integrationTests.summary.totalTests;
  totalPassed = unitTests.summary.testSuites.makeRelativePath.passedTests + integrationTests.summary.passedTests;
  totalFailed = unitTests.summary.testSuites.makeRelativePath.failedTests + integrationTests.summary.failedTests;

in rec {
  # Individual test suite results
  inherit unitTests integrationTests;

  # Unified summary across all test suites
  summary = {
    testSuites = allTestSuites;
    overall = {
      totalSuites = 2;
      totalTests = totalTests;
      totalPassed = totalPassed;
      totalFailed = totalFailed;
      allPassed = totalFailed == 0;
      suiteResults = [
        {
          name = "unit";
          passed = unitTests.summary.allSuitesPass;
          tests = unitTests.summary.testSuites.makeRelativePath.totalTests;
        }
        {
          name = "integration";
          passed = integrationTests.summary.allPassed;
          tests = integrationTests.summary.totalTests;
        }
      ];
    };
  };

  # Detailed results for debugging
  details = {
    unitTestDetails = unitTests.summary.testSuites.makeRelativePath.results;
    integrationTestDetails = integrationTests.summary.testResults;
    integrationDebugInfo = integrationTests.debug;
  };
}
