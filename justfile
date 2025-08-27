# Testing
# ========

# Run all tests and show results
test:
    #!/usr/bin/env bash
    echo "Running cabalPlan2nix test suite..."
    echo ""

    # Get test results
    results=$(nix eval -f test/ summary.overall --json 2>/dev/null)

    if [ $? -eq 0 ]; then
        # Show summary
        passed=$(echo "$results" | jq -r '.totalPassed')
        failed=$(echo "$results" | jq -r '.totalFailed')
        total=$(echo "$results" | jq -r '.totalTests')

        echo "Results: $passed passed, $failed failed, $total total"

        # Show suite breakdown
        echo ""
        echo "Test suites:"
        echo "$results" | jq -r '.suiteResults[] | "  \(.name): \(.tests) tests - \(if .passed then "✓ PASS" else "✗ FAIL" end)"'

        if [ "$failed" -eq 0 ]; then
            echo ""
            echo "✓ All tests passed!"
            exit 0
        else
            echo ""
            echo "✗ Some tests failed"
            exit 1
        fi
    else
        echo "Error running tests"
        exit 1
    fi

# Development
# ===========

# Build the flake
build:
    nix build

# Format Nix files using nixpkgs-fmt
fmt:
    nixpkgs-fmt .

# Enter development shell
dev:
    nix develop

# Check flake
check:
    nix flake check

# Show flake info
info:
    nix flake show
