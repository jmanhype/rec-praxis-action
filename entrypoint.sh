#!/bin/bash
set -e

shopt -s nullglob globstar

SCAN_TYPE="${1:-all}"
SEVERITY="${2:-HIGH}"
FAIL_ON="${3:-CRITICAL}"
FILES="${4:-**/*.py}"
FORMAT="${5:-json}"
MEMORY_DIR="${6:-.rec-praxis-rlm}"
INCREMENTAL="${7:-false}"
BASE_REF="${8:-origin/main}"
LANGUAGE="${9:-python}"

echo "::group::rec-praxis-rlm Configuration"
echo "Scan type: $SCAN_TYPE"
echo "Severity: $SEVERITY"
echo "Fail on: $FAIL_ON"
echo "Files: $FILES"
echo "Format: $FORMAT"
echo "Memory dir: $MEMORY_DIR"
echo "Incremental: $INCREMENTAL"
echo "Base ref: $BASE_REF"
echo "Language: $LANGUAGE"
echo "::endgroup::"

PYTHON_FILES=()

# Find Python files based on incremental mode
if [[ "$INCREMENTAL" == "true" ]]; then
    echo "::group::Finding Changed Python Files (Incremental Mode)"

    # Fetch base ref to ensure we have it
    git fetch origin --depth=1 2>/dev/null || echo "Warning: Could not fetch origin"

    # Get list of changed Python files compared to base ref
    mapfile -t CHANGED_FILES < <(git diff --name-only --diff-filter=ACMR "$BASE_REF"...HEAD | grep '\.py$' || true)

    if [ ${#CHANGED_FILES[@]} -eq 0 ]; then
        echo "No Python files changed in this PR/commit"
        echo "::endgroup::"
        echo "total-findings=0" >> $GITHUB_OUTPUT
        echo "blocking-findings=0" >> $GITHUB_OUTPUT
        echo "results-file=" >> $GITHUB_OUTPUT
        echo "::notice::No Python files to scan (incremental mode)"
        exit 0
    fi

    # Filter by patterns if specified
    if [[ "$FILES" != "**/*.py" ]]; then
        echo "Filtering changed files by pattern: $FILES"
        for file in "${CHANGED_FILES[@]}"; do
            for pattern in $FILES; do
                if [[ "$file" == $pattern ]]; then
                    PYTHON_FILES+=("$file")
                    break
                fi
            done
        done
    else
        PYTHON_FILES=("${CHANGED_FILES[@]}")
    fi

    echo "Changed files to scan: ${PYTHON_FILES[*]}"
    echo "::endgroup::"
elif [[ "$FILES" == *"*"* ]]; then
    echo "::group::Finding Python Files (Full Scan Mode)"
    for pattern in $FILES; do
        for f in $pattern; do
            case "$f" in
                */.venv/*|*/venv/*|*/node_modules/*) continue ;;
            esac
            PYTHON_FILES+=("$f")
        done
    done
    echo "Found files: ${PYTHON_FILES[*]}"
    echo "::endgroup::"
else
    read -r -a PYTHON_FILES <<< "$FILES"
fi

if [ ${#PYTHON_FILES[@]} -eq 0 ]; then
    echo "::notice::No Python files matched the provided patterns"
    echo "total-findings=0" >> $GITHUB_OUTPUT
    echo "blocking-findings=0" >> $GITHUB_OUTPUT
    echo "results-file=" >> $GITHUB_OUTPUT
    exit 0
fi

# Run the appropriate scan(s)
TOTAL_FINDINGS=0
BLOCKING_FINDINGS=0
RESULTS_FILE=""

run_code_review() {
    echo "::group::Running Code Review"
    if [ "$FORMAT" = "json" ] || [ "$FORMAT" = "sarif" ]; then
        rec-praxis-review "${PYTHON_FILES[@]}" \
            --severity="$SEVERITY" \
            --memory-dir="$MEMORY_DIR" \
            --format="$FORMAT" > code-review-results.$FORMAT || true

        REVIEW_TOTAL=$(cat code-review-results.$FORMAT | python3 -c "import sys, json; data=json.load(sys.stdin); print(len((data.get('runs') or [{}])[0].get('results', [])) if '$FORMAT' == 'sarif' else data.get('total_findings', 0))")
        REVIEW_BLOCKING=$(cat code-review-results.$FORMAT | python3 -c "import sys, json; data=json.load(sys.stdin); print(sum(1 for r in (data.get('runs') or [{}])[0].get('results', []) if r.get('level') == 'error') if '$FORMAT' == 'sarif' else data.get('blocking_findings', 0))")
        TOTAL_FINDINGS=$((TOTAL_FINDINGS + REVIEW_TOTAL))
        BLOCKING_FINDINGS=$((BLOCKING_FINDINGS + REVIEW_BLOCKING))
        echo "Found $REVIEW_TOTAL issue(s), $REVIEW_BLOCKING blocking"
    else
        rec-praxis-review "${PYTHON_FILES[@]}" \
            --severity="$SEVERITY" \
            --memory-dir="$MEMORY_DIR" \
            --format="$FORMAT" > code-review-results.$FORMAT
    fi
    echo "::endgroup::"
}

run_security_audit() {
    echo "::group::Running Security Audit"
    if [ "$FORMAT" = "json" ] || [ "$FORMAT" = "sarif" ]; then
        rec-praxis-audit "${PYTHON_FILES[@]}" \
            --memory-dir="$MEMORY_DIR" \
            --format="$FORMAT" > security-audit-results.$FORMAT || true

        AUDIT_TOTAL=$(cat security-audit-results.$FORMAT | python3 -c "import sys, json; data=json.load(sys.stdin); print(len((data.get('runs') or [{}])[0].get('results', [])) if '$FORMAT' == 'sarif' else data.get('total_findings', 0))")
        AUDIT_BLOCKING=$(cat security-audit-results.$FORMAT | python3 -c "import sys, json; data=json.load(sys.stdin); print(sum(1 for r in (data.get('runs') or [{}])[0].get('results', []) if r.get('level') == 'error') if '$FORMAT' == 'sarif' else data.get('blocking_findings', 0))")
        TOTAL_FINDINGS=$((TOTAL_FINDINGS + AUDIT_TOTAL))
        BLOCKING_FINDINGS=$((BLOCKING_FINDINGS + AUDIT_BLOCKING))
        echo "Found $AUDIT_TOTAL issue(s), $AUDIT_BLOCKING blocking"
    else
        rec-praxis-audit "${PYTHON_FILES[@]}" \
            --memory-dir="$MEMORY_DIR" \
            --format="$FORMAT" > security-audit-results.$FORMAT
    fi
    echo "::endgroup::"
}

run_dependency_scan() {
    echo "::group::Running Dependency & Secret Scan"
    if [ "$FORMAT" = "json" ] || [ "$FORMAT" = "sarif" ]; then
        rec-praxis-deps "${PYTHON_FILES[@]}" \
            --memory-dir="$MEMORY_DIR" \
            --format="$FORMAT" > dependency-scan-results.$FORMAT || true

        DEPS_TOTAL=$(cat dependency-scan-results.$FORMAT | python3 -c "import sys, json; data=json.load(sys.stdin); print(len((data.get('runs') or [{}])[0].get('results', [])) if '$FORMAT' == 'sarif' else data.get('total_findings', 0))")
        DEPS_BLOCKING=$(cat dependency-scan-results.$FORMAT | python3 -c "import sys, json; data=json.load(sys.stdin); print(sum(1 for r in (data.get('runs') or [{}])[0].get('results', []) if r.get('level') == 'error') if '$FORMAT' == 'sarif' else data.get('blocking_findings', 0))")
        TOTAL_FINDINGS=$((TOTAL_FINDINGS + DEPS_TOTAL))
        BLOCKING_FINDINGS=$((BLOCKING_FINDINGS + DEPS_BLOCKING))
        echo "Found $DEPS_TOTAL issue(s), $DEPS_BLOCKING blocking"
    else
        rec-praxis-deps "${PYTHON_FILES[@]}" \
            --memory-dir="$MEMORY_DIR" \
            --format="$FORMAT" > dependency-scan-results.$FORMAT
    fi
    echo "::endgroup::"
}

# JavaScript/TypeScript scanning functions
run_eslint_scan() {
    echo "::group::Running ESLint Security Scan"

    # Find JS/TS files
    JS_FILES=$(find . -name "*.js" -o -name "*.ts" -o -name "*.jsx" -o -name "*.tsx" | grep -v node_modules | tr '\n' ' ' || echo "")

    if [ -z "$JS_FILES" ]; then
        echo "No JavaScript/TypeScript files found"
        echo "::endgroup::"
        return 0
    fi

    # Install ESLint security plugins if package.json exists
    if [ -f "package.json" ]; then
        npm install --no-save eslint-plugin-security eslint-plugin-no-secrets 2>/dev/null || true
    fi

    # Run ESLint with security plugins
    npx eslint \
        --plugin security \
        --rule 'security/detect-object-injection: warn' \
        --rule 'security/detect-non-literal-regexp: warn' \
        --rule 'security/detect-unsafe-regex: error' \
        --rule 'security/detect-buffer-noassert: error' \
        --rule 'security/detect-child-process: warn' \
        --rule 'security/detect-disable-mustache-escape: error' \
        --rule 'security/detect-eval-with-expression: error' \
        --rule 'security/detect-no-csrf-before-method-override: error' \
        --rule 'security/detect-possible-timing-attacks: warn' \
        --format json \
        $JS_FILES > eslint-results.json 2>/dev/null || true

    # Count findings
    if [ -f "eslint-results.json" ]; then
        ESLINT_TOTAL=$(python3 -c "import sys, json; data=json.load(open('eslint-results.json')); print(sum(len(f.get('messages', [])) for f in data))" 2>/dev/null || echo "0")
        ESLINT_BLOCKING=$(python3 -c "import sys, json; data=json.load(open('eslint-results.json')); print(sum(1 for f in data for m in f.get('messages', []) if m.get('severity') == 2))" 2>/dev/null || echo "0")
        TOTAL_FINDINGS=$((TOTAL_FINDINGS + ESLINT_TOTAL))
        BLOCKING_FINDINGS=$((BLOCKING_FINDINGS + ESLINT_BLOCKING))
        echo "Found $ESLINT_TOTAL issue(s), $ESLINT_BLOCKING errors"
    fi
    echo "::endgroup::"
}

run_npm_audit() {
    echo "::group::Running npm audit"

    if [ ! -f "package.json" ]; then
        echo "No package.json found, skipping npm audit"
        echo "::endgroup::"
        return 0
    fi

    # Run npm audit
    npm audit --json > npm-audit-results.json 2>/dev/null || true

    # Count vulnerabilities
    if [ -f "npm-audit-results.json" ]; then
        NPM_CRITICAL=$(python3 -c "import sys, json; data=json.load(open('npm-audit-results.json')); print(data.get('metadata', {}).get('vulnerabilities', {}).get('critical', 0))" 2>/dev/null || echo "0")
        NPM_HIGH=$(python3 -c "import sys, json; data=json.load(open('npm-audit-results.json')); print(data.get('metadata', {}).get('vulnerabilities', {}).get('high', 0))" 2>/dev/null || echo "0")
        NPM_TOTAL=$((NPM_CRITICAL + NPM_HIGH))
        TOTAL_FINDINGS=$((TOTAL_FINDINGS + NPM_TOTAL))
        BLOCKING_FINDINGS=$((BLOCKING_FINDINGS + NPM_CRITICAL))
        echo "Found $NPM_TOTAL vulnerability(ies), $NPM_CRITICAL critical"
    fi
    echo "::endgroup::"
}

run_typescript_check() {
    echo "::group::Running TypeScript Compiler Check"

    if [ ! -f "tsconfig.json" ]; then
        echo "No tsconfig.json found, skipping TypeScript check"
        echo "::endgroup::"
        return 0
    fi

    # Run TypeScript compiler
    npx tsc --noEmit --pretty false > tsc-results.txt 2>&1 || true

    # Count errors
    if [ -f "tsc-results.txt" ]; then
        TSC_ERRORS=$(grep -c "error TS" tsc-results.txt 2>/dev/null || echo "0")
        TOTAL_FINDINGS=$((TOTAL_FINDINGS + TSC_ERRORS))
        echo "Found $TSC_ERRORS type error(s)"
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
    review-js)
        run_eslint_scan
        run_typescript_check
        RESULTS_FILE="eslint-results.json"
        ;;
    audit-js)
        run_eslint_scan
        RESULTS_FILE="eslint-results.json"
        ;;
    deps-js)
        run_npm_audit
        RESULTS_FILE="npm-audit-results.json"
        ;;
    all-js)
        run_eslint_scan
        run_typescript_check
        run_npm_audit
        RESULTS_FILE="eslint-results.json"
        ;;
    *)
        echo "::error::Invalid scan type: $SCAN_TYPE. Use: review, audit, deps, all, review-js, audit-js, deps-js, or all-js"
        exit 1
        ;;
esac

if [ "$SCAN_TYPE" = "all" ]; then
    cat > rec-praxis-results-index.json <<EOF
{
  "code_review": "code-review-results.$FORMAT",
  "security_audit": "security-audit-results.$FORMAT",
  "dependency_scan": "dependency-scan-results.$FORMAT"
}
EOF
    RESULTS_FILE="rec-praxis-results-index.json"
fi

# Compress SARIF files if format is sarif (reduces artifact storage by ~70%)
if [ "$FORMAT" = "sarif" ]; then
    echo "::group::Compressing SARIF Files"
    for sarif_file in *.sarif; do
        if [ -f "$sarif_file" ]; then
            gzip -k "$sarif_file"  # Keep original + create .gz
            original_size=$(stat -f%z "$sarif_file" 2>/dev/null || stat -c%s "$sarif_file" 2>/dev/null || echo "0")
            compressed_size=$(stat -f%z "$sarif_file.gz" 2>/dev/null || stat -c%s "$sarif_file.gz" 2>/dev/null || echo "0")

            if [ "$original_size" -gt 0 ]; then
                reduction=$((100 - (compressed_size * 100 / original_size)))
                echo "Compressed $sarif_file: ${original_size}B → ${compressed_size}B (${reduction}% reduction)"
            fi
        fi
    done
    echo "::endgroup::"
fi

# Set outputs
echo "total-findings=$TOTAL_FINDINGS" >> $GITHUB_OUTPUT
echo "blocking-findings=$BLOCKING_FINDINGS" >> $GITHUB_OUTPUT
echo "results-file=$RESULTS_FILE" >> $GITHUB_OUTPUT

# Summary
echo "::group::Summary"
echo "Total findings: $TOTAL_FINDINGS"
echo "Blocking findings: $BLOCKING_FINDINGS"
if [ "$FORMAT" = "sarif" ]; then
    echo "SARIF files compressed (gzip) for efficient artifact storage"
fi
echo "::endgroup::"

# Fail if blocking findings exist
if [ "$BLOCKING_FINDINGS" -gt 0 ]; then
    echo "::error::Found $BLOCKING_FINDINGS blocking issue(s) at $FAIL_ON severity or higher"
    exit 1
fi

echo "::notice::rec-praxis-rlm scan completed successfully"
exit 0
