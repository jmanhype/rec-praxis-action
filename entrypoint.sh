#!/bin/bash
set -e

SCAN_TYPE="${1:-all}"
SEVERITY="${2:-HIGH}"
FAIL_ON="${3:-CRITICAL}"
FILES="${4:-**/*.py}"
FORMAT="${5:-json}"
MEMORY_DIR="${6:-.rec-praxis-rlm}"

echo "::group::rec-praxis-rlm Configuration"
echo "Scan type: $SCAN_TYPE"
echo "Severity: $SEVERITY"
echo "Fail on: $FAIL_ON"
echo "Files: $FILES"
echo "Format: $FORMAT"
echo "Memory dir: $MEMORY_DIR"
echo "::endgroup::"

# Find Python files if using glob pattern
if [[ "$FILES" == *"*"* ]]; then
    echo "::group::Finding Python files"
    PYTHON_FILES=$(find . -name "*.py" -type f | grep -v ".venv" | grep -v "venv" | grep -v "node_modules" | tr '\n' ' ')
    echo "Found files: $PYTHON_FILES"
    echo "::endgroup::"
else
    PYTHON_FILES="$FILES"
fi

# Run the appropriate scan(s)
TOTAL_FINDINGS=0
BLOCKING_FINDINGS=0
RESULTS_FILE=""

run_code_review() {
    echo "::group::Running Code Review"
    rec-praxis-review $PYTHON_FILES \
        --severity="$SEVERITY" \
        --memory-dir="$MEMORY_DIR" \
        --format="$FORMAT" > code-review-results.$FORMAT || true

    if [ "$FORMAT" = "json" ] || [ "$FORMAT" = "sarif" ]; then
        REVIEW_TOTAL=$(cat code-review-results.$FORMAT | python3 -c "import sys, json; data=json.load(sys.stdin); print(len(data.get('runs', [{}])[0].get('results', [])) if '$FORMAT' == 'sarif' else data.get('total_findings', 0))")
        REVIEW_BLOCKING=$(cat code-review-results.$FORMAT | python3 -c "import sys, json; data=json.load(sys.stdin); print(sum(1 for r in data.get('runs', [{}])[0].get('results', []) if r.get('level') == 'error') if '$FORMAT' == 'sarif' else data.get('blocking_findings', 0))")
        TOTAL_FINDINGS=$((TOTAL_FINDINGS + REVIEW_TOTAL))
        BLOCKING_FINDINGS=$((BLOCKING_FINDINGS + REVIEW_BLOCKING))
        echo "Found $REVIEW_TOTAL issue(s), $REVIEW_BLOCKING blocking"
    fi
    echo "::endgroup::"
}

run_security_audit() {
    echo "::group::Running Security Audit"
    rec-praxis-audit $PYTHON_FILES \
        --fail-on="$FAIL_ON" \
        --memory-dir="$MEMORY_DIR" \
        --format="$FORMAT" > security-audit-results.$FORMAT || true

    if [ "$FORMAT" = "json" ] || [ "$FORMAT" = "sarif" ]; then
        AUDIT_TOTAL=$(cat security-audit-results.$FORMAT | python3 -c "import sys, json; data=json.load(sys.stdin); print(len(data.get('runs', [{}])[0].get('results', [])) if '$FORMAT' == 'sarif' else data.get('total_findings', 0))")
        AUDIT_BLOCKING=$(cat security-audit-results.$FORMAT | python3 -c "import sys, json; data=json.load(sys.stdin); print(sum(1 for r in data.get('runs', [{}])[0].get('results', []) if r.get('level') == 'error') if '$FORMAT' == 'sarif' else data.get('blocking_findings', 0))")
        TOTAL_FINDINGS=$((TOTAL_FINDINGS + AUDIT_TOTAL))
        BLOCKING_FINDINGS=$((BLOCKING_FINDINGS + AUDIT_BLOCKING))
        echo "Found $AUDIT_TOTAL issue(s), $AUDIT_BLOCKING critical"
    fi
    echo "::endgroup::"
}

run_dependency_scan() {
    echo "::group::Running Dependency & Secret Scan"
    rec-praxis-deps \
        --fail-on="$FAIL_ON" \
        --memory-dir="$MEMORY_DIR" \
        --format="$FORMAT" > dependency-scan-results.$FORMAT || true

    if [ "$FORMAT" = "json" ] || [ "$FORMAT" = "sarif" ]; then
        DEPS_TOTAL=$(cat dependency-scan-results.$FORMAT | python3 -c "import sys, json; data=json.load(sys.stdin); print(len(data.get('runs', [{}])[0].get('results', [])) if '$FORMAT' == 'sarif' else data.get('total_findings', 0))")
        DEPS_BLOCKING=$(cat dependency-scan-results.$FORMAT | python3 -c "import sys, json; data=json.load(sys.stdin); print(sum(1 for r in data.get('runs', [{}])[0].get('results', []) if r.get('level') == 'error') if '$FORMAT' == 'sarif' else data.get('blocking_findings', 0))")
        TOTAL_FINDINGS=$((TOTAL_FINDINGS + DEPS_TOTAL))
        BLOCKING_FINDINGS=$((BLOCKING_FINDINGS + DEPS_BLOCKING))
        echo "Found $DEPS_TOTAL issue(s), $DEPS_BLOCKING critical"
    fi
    echo "::endgroup::"
}

# Execute scans based on type
case "$SCAN_TYPE" in
    review)
        run_code_review
        RESULTS_FILE="code-review-results.$FORMAT"
        ;;
    audit)
        run_security_audit
        RESULTS_FILE="security-audit-results.$FORMAT"
        ;;
    deps)
        run_dependency_scan
        RESULTS_FILE="dependency-scan-results.$FORMAT"
        ;;
    all)
        run_code_review
        run_security_audit
        run_dependency_scan
        RESULTS_FILE="code-review-results.$FORMAT"
        ;;
    *)
        echo "::error::Invalid scan type: $SCAN_TYPE. Use: review, audit, deps, or all"
        exit 1
        ;;
esac

# Set outputs
echo "total-findings=$TOTAL_FINDINGS" >> $GITHUB_OUTPUT
echo "blocking-findings=$BLOCKING_FINDINGS" >> $GITHUB_OUTPUT
echo "results-file=$RESULTS_FILE" >> $GITHUB_OUTPUT

# Summary
echo "::group::Summary"
echo "Total findings: $TOTAL_FINDINGS"
echo "Blocking findings: $BLOCKING_FINDINGS"
echo "::endgroup::"

# Fail if blocking findings exist
if [ "$BLOCKING_FINDINGS" -gt 0 ]; then
    echo "::error::Found $BLOCKING_FINDINGS blocking issue(s) at $FAIL_ON severity or higher"
    exit 1
fi

echo "::notice::rec-praxis-rlm scan completed successfully"
exit 0
