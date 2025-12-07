# rec-praxis-rlm Security Scanner GitHub Action

Automated code review, security auditing, and dependency scanning powered by procedural memory AI agents. Integrates rec-praxis-rlm into your CI/CD pipeline with zero configuration.

## Features

- **🔍 Code Review**: Pattern-based detection of code quality issues with AI-powered suggestions
- **🔒 Security Audit**: OWASP Top 10 detection, CWE mapping, vulnerability identification
- **📦 Dependency Scanning**: CVE detection in Python packages + secret/credential scanning
- **🧠 Procedural Memory**: Learns from past fixes and improves recommendations over time
- **⚡ Token-Efficient**: Optional TOON format reduces LLM token usage by 40-50%

## Quick Start

Add to your workflow `.github/workflows/security-scan.yml`:

```yaml
name: Security Scan

on: [push, pull_request]

jobs:
  security:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Run rec-praxis-rlm Security Scanner
        uses: jmanhype/rec-praxis-action@v1
        with:
          scan-type: 'all'
          severity: 'HIGH'
          fail-on: 'CRITICAL'
```

## Inputs

| Input | Description | Default |
|-------|-------------|---------|
| `scan-type` | Type of scan: `review`, `audit`, `deps`, or `all` | `all` |
| `severity` | Minimum severity to report (LOW, MEDIUM, HIGH, CRITICAL) | `HIGH` |
| `fail-on` | Fail build at this severity or higher | `CRITICAL` |
| `files` | Files or patterns to scan (space-separated) | `**/*.py` |
| `format` | Output format: `json`, `toon`, `sarif`, or `text` | `json` |
| `memory-dir` | Directory for procedural memory storage | `.rec-praxis-rlm` |
| `incremental` | Only scan files changed in PR/commit (true/false) | `false` |
| `base-ref` | Base git ref for incremental scan | `origin/main` |

## Outputs

| Output | Description |
|--------|-------------|
| `total-findings` | Total number of issues found across all scans |
| `blocking-findings` | Number of issues at fail-on severity or higher |
| `results-file` | Path to the results file (for artifact upload) |

## Usage Examples

### Code Review Only

```yaml
- uses: jmanhype/rec-praxis-action@v1
  with:
    scan-type: 'review'
    severity: 'MEDIUM'
```

### Security Audit with Strict Failure

```yaml
- uses: jmanhype/rec-praxis-action@v1
  with:
    scan-type: 'audit'
    fail-on: 'HIGH'
```

### Dependency Scanning with Custom Files

```yaml
- uses: jmanhype/rec-praxis-action@v1
  with:
    scan-type: 'deps'
    files: 'src/**/*.py tests/**/*.py'
```

### Incremental Scanning (Changed Files Only)

Scan only files modified in the PR - significantly faster for large codebases:

```yaml
- uses: jmanhype/rec-praxis-action@v1
  with:
    incremental: 'true'
    base-ref: 'origin/main'  # Compare against main branch
```

**Benefits**:
- 10-100x faster for large repositories
- Only scans files actually changed in the PR
- Perfect for pull request workflows
- Uses git diff to detect changes

**Example for PR workflow**:
```yaml
on:
  pull_request:
    branches: [main]

jobs:
  security:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0  # Full history for git diff

      - uses: jmanhype/rec-praxis-action@v1
        with:
          incremental: 'true'
          base-ref: 'origin/${{ github.base_ref }}'
```

### TOON Format (Token-Efficient)

Save LLM tokens when processing results with AI:

```yaml
- uses: jmanhype/rec-praxis-action@v1
  with:
    format: 'toon'

- name: Upload results
  uses: actions/upload-artifact@v4
  with:
    name: security-scan-results
    path: '*.toon'
```

### SARIF Output for GitHub Security Tab

Integrate findings directly into GitHub Security tab (Code Scanning):

```yaml
- uses: jmanhype/rec-praxis-action@v1
  with:
    format: 'sarif'

- name: Upload SARIF to GitHub Security
  if: always()
  uses: github/codeql-action/upload-sarif@v2
  with:
    sarif_file: code-review-results.sarif
    category: rec-praxis-code-review

- name: Upload Security Audit SARIF
  if: always()
  uses: github/codeql-action/upload-sarif@v2
  with:
    sarif_file: security-audit-results.sarif
    category: rec-praxis-security-audit
```

**Benefits**:
- Findings appear in GitHub Security tab alongside CodeQL and Dependabot
- Automatic OWASP/CWE categorization
- Filterable by severity (error = CRITICAL/HIGH, warning = MEDIUM/LOW)
- Trackable across commits

### Full Workflow with Artifacts

```yaml
name: Comprehensive Security Scan

on:
  pull_request:
    branches: [main]
  push:
    branches: [main]

jobs:
  security:
    runs-on: ubuntu-latest
    permissions:
      contents: read
      security-events: write

    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Run rec-praxis-rlm Scanner
        id: scan
        uses: jmanhype/rec-praxis-action@v1
        with:
          scan-type: 'all'
          severity: 'MEDIUM'
          fail-on: 'HIGH'
          format: 'json'

      - name: Upload scan results
        if: always()
        uses: actions/upload-artifact@v4
        with:
          name: rec-praxis-scan-results
          path: |
            code-review-results.json
            security-audit-results.json
            dependency-scan-results.json
          retention-days: 90  # Keep artifacts for 90 days

      - name: Summary
        if: always()
        run: |
          echo "### Security Scan Results" >> $GITHUB_STEP_SUMMARY
          echo "- Total findings: ${{ steps.scan.outputs.total-findings }}" >> $GITHUB_STEP_SUMMARY
          echo "- Blocking findings: ${{ steps.scan.outputs.blocking-findings }}" >> $GITHUB_STEP_SUMMARY
```

### Compressed SARIF Artifacts (Recommended)

SARIF files are automatically compressed with gzip (~70% size reduction) for efficient storage:

```yaml
- name: Run Security Scan (SARIF)
  uses: jmanhype/rec-praxis-action@v1
  with:
    format: 'sarif'

- name: Upload Compressed SARIF
  if: always()
  uses: actions/upload-artifact@v4
  with:
    name: security-sarif-reports
    path: '*.sarif.gz'  # Upload compressed files
    retention-days: 30
    compression-level: 0  # Already compressed, skip re-compression

- name: Upload Original SARIF (for GitHub Security Tab)
  if: always()
  uses: github/codeql-action/upload-sarif@v2
  with:
    sarif_file: code-review-results.sarif  # Use uncompressed for upload
```

**Benefits**:
- 70% reduction in artifact storage costs
- Faster artifact uploads/downloads
- Both compressed (.gz) and original files available
- GitHub Security Tab still receives uncompressed SARIF

### PR Comment with Findings

Combine with GitHub Script to post results as PR comments:

```yaml
- name: Run Security Scan
  id: scan
  uses: jmanhype/rec-praxis-action@v1
  with:
    scan-type: 'all'
    format: 'json'
  continue-on-error: true

- name: Comment PR
  if: github.event_name == 'pull_request'
  uses: actions/github-script@v7
  with:
    script: |
      const fs = require('fs');
      const results = JSON.parse(fs.readFileSync('code-review-results.json', 'utf8'));

      let comment = `## 🔍 Security Scan Results\n\n`;
      comment += `**Found ${results.total_findings} issue(s)**\n\n`;

      if (results.findings.length > 0) {
        comment += `| File | Line | Severity | Issue |\n`;
        comment += `|------|------|----------|-------|\n`;
        for (const finding of results.findings.slice(0, 10)) {
          comment += `| ${finding.file} | ${finding.line || 'N/A'} | ${finding.severity} | ${finding.title} |\n`;
        }
      }

      github.rest.issues.createComment({
        issue_number: context.issue.number,
        owner: context.repo.owner,
        repo: context.repo.repo,
        body: comment
      });
```

## What It Detects

### Code Review
- SQL injection patterns
- Hardcoded credentials (API keys, passwords, tokens)
- Weak cryptography (MD5, SHA1)
- Bare except blocks
- Shell injection via subprocess
- Dangerous code execution (eval/exec)

### Security Audit
- OWASP Top 10 vulnerabilities
- CWE-mapped security issues
- Authentication and authorization flaws
- Data exposure risks

### Dependency Scanning
- CVE vulnerabilities in Python packages
- Exposed secrets and API keys
- High-entropy strings (potential credentials)
- Outdated dependencies

## Procedural Memory

rec-praxis-rlm **learns from your fixes**:

1. **First scan**: Detects SQL injection
2. **You fix it**: Apply parameterized queries
3. **Agent stores experience**: "SQL injection → params = success"
4. **Next scan**: Agent recalls this pattern and provides better suggestions

Memory is stored in `.rec-praxis-rlm/` directory (can be customized via `memory-dir` input).

## Artifact Storage Optimization

### Automatic SARIF Compression

When using `format: 'sarif'`, the action automatically compresses SARIF files with gzip:

- **Storage Reduction**: ~70% smaller artifacts
- **Cost Savings**: Reduced GitHub Actions storage costs
- **Dual Output**: Both `.sarif` (for GitHub Security) and `.sarif.gz` (for archival)
- **Transparent**: No changes needed in your workflow

### Recommended Retention Policies

Balance security audit history with storage costs:

| Artifact Type | Retention | Use Case |
|---------------|-----------|----------|
| JSON results | 90 days | Long-term trend analysis |
| SARIF (compressed) | 30 days | Security tab integration |
| TOON format | 7 days | Short-term LLM processing |

**Example with retention**:
```yaml
- uses: actions/upload-artifact@v4
  with:
    name: security-results
    path: '*.sarif.gz'
    retention-days: 30
```

## Performance

- **Fast**: Scans 1000 lines of Python in ~2-5 seconds
- **Token-efficient**: TOON format reduces token usage by 40-50%
- **Lightweight**: Docker image is ~500MB
- **Storage-optimized**: SARIF compression reduces artifact size by 70%

## Requirements

- GitHub Actions runner (ubuntu-latest, windows-latest, macos-latest)
- Python files in repository
- No additional setup required (Python + dependencies included in Docker image)

## Versioning

Use specific versions for stability:

```yaml
uses: jmanhype/rec-praxis-action@v1.0.0  # Specific version
uses: jmanhype/rec-praxis-action@v1      # Latest v1.x
uses: jmanhype/rec-praxis-action@main    # Latest (unstable)
```

## Related Projects

- [rec-praxis-rlm](https://github.com/jmanhype/rec-praxis-rlm) - Python package
- [rec-praxis-rlm PyPI](https://pypi.org/project/rec-praxis-rlm/) - Install locally
- [VS Code Extension](https://github.com/jmanhype/rec-praxis-rlm/tree/main/vscode-extension) - IDE integration

## License

MIT License - See [LICENSE](LICENSE) file

## Support

- [Report Issues](https://github.com/jmanhype/rec-praxis-action/issues)
- [Documentation](https://github.com/jmanhype/rec-praxis-rlm#readme)
- [PyPI Package](https://pypi.org/project/rec-praxis-rlm/)
