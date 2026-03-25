# rec-praxis-action

GitHub Action that runs `rec-praxis-rlm` code review, security audit, and dependency scanning in CI. Ships as a Docker container with Python 3.11, Node.js 20, and all scanner dependencies pre-installed.

| | |
|---|---|
| Version | 1.2.0 |
| Base image | python:3.11-slim (multi-stage) |
| Scanner version | rec-praxis-rlm 0.9.2 |
| Languages | Python, JavaScript, TypeScript |
| License | MIT |

## What it does

Wraps 3 CLI tools from `rec-praxis-rlm` into a single GitHub Action:

| Scan type | Tool | What it checks |
|---|---|---|
| `review` | `rec-praxis-review` | Code quality patterns, style issues |
| `audit` | `rec-praxis-audit` | OWASP Top 10, CWE-mapped vulnerabilities |
| `deps` | `rec-praxis-deps` | Known CVEs in dependencies, hardcoded secrets |
| `all` | All 3 above | Combined scan |

JS/TS variants available: `review-js`, `audit-js`, `deps-js`, `all-js`.

## Inputs

| Input | Type | Default | Description |
|---|---|---|---|
| `scan-type` | string | `all` | `review`, `audit`, `deps`, `all` (and `-js` variants) |
| `language` | string | `python` | `python`, `javascript`, `typescript`, `auto-detect` |
| `severity` | string | `HIGH` | Minimum severity to report. Only applies to `review` scans. |
| `fail-on` | string | `CRITICAL` | Fail the build at this severity or higher |
| `files` | string | `**/*.py` | Space-separated file globs. Skips `.venv`, `venv`, `node_modules`. |
| `format` | string | `json` | `json`, `sarif`, `toon`, `text` |
| `memory-dir` | string | `.rec-praxis-rlm` | Directory for procedural memory storage |
| `incremental` | bool | `false` | Only scan files changed in PR/commit |
| `base-ref` | string | `origin/main` | Base ref for incremental diff |

## Outputs

| Output | Description |
|---|---|
| `total-findings` | Number of issues found across all scans |
| `blocking-findings` | Number of issues at `fail-on` severity or higher |
| `results-file` | Path to results file (index JSON for `all` scans) |

## Basic usage

```yaml
name: Security Scan
on: [push, pull_request]

jobs:
  security:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: jmanhype/rec-praxis-action@v1
        with:
          scan-type: 'all'
          severity: 'HIGH'
          fail-on: 'CRITICAL'
```

## Incremental scanning

Scan only files changed in the PR. Requires `fetch-depth: 0` for git history.

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
          fetch-depth: 0
      - uses: jmanhype/rec-praxis-action@v1
        with:
          incremental: 'true'
          base-ref: 'origin/${{ github.base_ref }}'
```

## SARIF output

Push findings to the GitHub Security tab:

```yaml
- uses: jmanhype/rec-praxis-action@v1
  with:
    format: 'sarif'

- uses: github/codeql-action/upload-sarif@v2
  if: always()
  with:
    sarif_file: code-review-results.sarif
    category: rec-praxis-code-review
```

Requires `security-events: write` permission on the job.

## Docker image

Two-stage build:

1. **Builder** -- installs gcc/g++, builds `rec-praxis-rlm[all]==0.9.2` into a venv.
2. **Runtime** -- copies venv, adds git + Node.js 20 + eslint/typescript.

| Metric | Value |
|---|---|
| First build | ~60s |
| Cached rebuild | ~10-15s |
| Entrypoint-only change | ~2s |

Local testing:

```bash
docker build -t rec-praxis-action .
docker run -v $(pwd):/github/workspace rec-praxis-action all HIGH CRITICAL "*.py" json
```

## Limitations

- Pattern-based detection only. No semantic/LLM analysis yet.
- The `severity` filter only applies to `review` scans; `audit` and `deps` return all findings regardless.
- `toon` and `text` formats do not parse finding counts; exit code controls pass/fail.
- LLM-powered analysis inputs (`use-llm`, `lm-model`) are present but non-functional. Requires upstream changes to `rec-praxis-rlm` v0.10.0 that have not shipped.
- Procedural memory accumulates across runs only if you persist the `memory-dir` between workflow runs (not done by default).

## Versioning

```yaml
uses: jmanhype/rec-praxis-action@v1.0.0  # pinned
uses: jmanhype/rec-praxis-action@v1      # latest v1.x
uses: jmanhype/rec-praxis-action@main    # latest (unstable)
```

## Related

- [rec-praxis-rlm](https://github.com/jmanhype/rec-praxis-rlm) -- underlying Python package
- [PyPI](https://pypi.org/project/rec-praxis-rlm/)

## License

MIT
