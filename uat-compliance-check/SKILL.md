---
name: uat-compliance-check
description: >
  Audit a codebase for UAT/production compliance against SEC-STD-001 guidelines.
  Use when asked to: check, audit, scan, review, or validate a repository for
  security compliance, credential leaks, configuration safety, missing required files,
  hardcoded secrets/IPs, Dockerfile issues, .gitignore/.dockerignore problems,
  or pre-merge/pre-deploy readiness. Covers Exchange platform services (Go, Java/Spring Boot, Flutter).
---

# UAT Codebase Compliance Check

Audit a repository against the UAT Codebase Compliance Guidelines (SEC-STD-001).
Full specification: [references/compliance-guidelines.md](references/compliance-guidelines.md)

## Workflow

### 1. Determine project type

Inspect root files to classify: **Go** (`go.mod`), **Java** (`pom.xml`/`build.gradle`), or **Flutter** (`pubspec.yaml`).
If ambiguous, check for multiple indicators and ask the user.

### 2. Run the 12-point checklist

Execute each check below in order. For every check, record **PASS**, **FAIL** (mandatory violation), or **WARN** (recommended but not blocking).

| #  | Check | How to verify | Severity on fail |
|----|-------|---------------|------------------|
| 1  | No credential files tracked | `git ls-files` for `.env`, `.env.*` (not `.env.example`), `.netrc`, `credentials.json`, `serviceAccount.json`, `*.pem`, `*.key`, `*.p12`, `*.pfx`, `*.jks`, `id_rsa`, `id_ed25519`, `data/private/` | **Critical** |
| 2  | Git history clean | Run `gitleaks detect --source . --log-opts="--all"` (if available) or grep git log for password/dsn/secret/token patterns | **Critical** |
| 3  | `.gitignore` compliant | Exists; contains all L1 patterns from spec; does NOT contain `*_test.go`, `*Test.java`, `*_test.dart`, `go.sum`, `Dockerfile` | **High** |
| 4  | `.dockerignore` exists | File present; excludes `.git`, `.env`, `*.pem`, `*.key`, `.netrc`, `data/private/` | **Medium** |
| 5  | Dockerfile secure | Uses BuildKit secrets (no `COPY .netrc`); has `USER` before `ENTRYPOINT`; no `COPY data/private/` | **High** |
| 6  | Safe default config | In config files (`config.toml`, `application.yml`): `debug=false`, `gin_debug=false`, `log_min_level≥warn`, `swagger=false`, `request_log=false`, `response_log=false`, `db_log=false` | **High** |
| 7  | No hardcoded IPs | Scan `Makefile`, `*.yaml`, `*.yml`, `*.toml`, `*.hcl` for private IPs (`10.x`, `172.16-31.x`, `192.168.x`), Nomad/K8s endpoints | **High** |
| 8  | Test files tracked | `*_test.go` / `*Test.java` / `*_test.dart` exist and are tracked by git | **High** |
| 9  | Required docs present | `README.md`, `SECURITY.md`, `CHANGELOG.md` all exist | **Medium** (WARN for each missing) |
| 10 | Pre-commit hooks configured | `.pre-commit-config.yaml` exists and includes gitleaks | **Medium** |
| 11 | CI has security scan | `.gitlab-ci.yml` (or equivalent) includes a gitleaks/secret-scanning stage | **Medium** |
| 12 | No audit reports tracked | No `*_Code_Review_Report.*` files in repo | **Medium** |

### 3. Check for hardcoded secrets in source code

Beyond file-level checks, scan source files for inline secrets:
- Database connection strings with embedded passwords (`user:pass@`)
- Strings matching `(?i)(api[_-]?key|api[_-]?token|access[_-]?token)\s*[:=]\s*["']?[a-zA-Z0-9_\-]{20,}`
- Private keys embedded in code

### 4. Produce the report

Output a structured compliance report:

```
# UAT Compliance Audit Report
**Repository:** <name>
**Project type:** Go | Java | Flutter
**Date:** <date>
**Standard:** SEC-STD-001 v1.0

## Summary
- Critical: X issues
- High: X issues
- Medium: X issues
- WARN: X items

## Findings

### [CRITICAL] #1 — <title>
- **Files:** <list>
- **Detail:** <what was found>
- **Required action:** <what to do>
- **Deadline:** Immediate (2h)

### [HIGH] #N — <title>
...

## Checklist Results
| # | Check | Result | Notes |
|---|-------|--------|-------|
| 1 | No credential files | PASS/FAIL | ... |
...

## Recommended Fix Order
1. Critical items first (credential rotation + history cleanup)
2. High items (config, Dockerfile, hardcoded IPs)
3. Medium items (missing docs, tooling)
```

### 5. Severity reference

| Level | Deadline | Examples |
|-------|----------|---------|
| **Critical** | Immediate (2h) | Production credentials in repo/history |
| **High** | 24 hours | Hardcoded IPs, debug=true defaults, Dockerfile security issues |
| **Medium** | 1 week | Missing .dockerignore, no pre-commit hooks |
| **Low** | 2 weeks | Missing SECURITY.md, CHANGELOG.md |

## Verification commands

```bash
# Check tracked credential files
git ls-files | grep -iE '\.env$|\.env\.|\.netrc|credentials\.json|serviceAccount\.json|\.pem$|\.key$|\.p12$|\.pfx$|\.jks$|id_rsa|id_ed25519|data/private'

# Check .gitignore doesn't block tests
grep -n '_test\.' .gitignore

# Find hardcoded private IPs
grep -rnE '(10\.[0-9]+\.[0-9]+\.[0-9]+|172\.(1[6-9]|2[0-9]|3[01])\.[0-9]+\.[0-9]+|192\.168\.[0-9]+\.[0-9]+)' --include='*.go' --include='*.java' --include='*.toml' --include='*.yaml' --include='*.yml' --include='Makefile' .

# Find debug=true in configs
grep -rnE '(debug|gin_debug|request_log|response_log|db_log)\s*[=:]\s*(true|"true")' --include='*.toml' --include='*.yaml' --include='*.yml' .

# Check Dockerfile for COPY .netrc
grep -nE 'COPY.*\.netrc' Dockerfile 2>/dev/null

# Check USER before ENTRYPOINT in Dockerfile
awk '/^USER /{u=NR} /^ENTRYPOINT/{e=NR} END{if(e && (!u || u>e)) print "FAIL: USER must come before ENTRYPOINT"}' Dockerfile 2>/dev/null
```

## Notes

- For full file classification rules (L1–L4), config architecture, and directory structure templates, read [references/compliance-guidelines.md](references/compliance-guidelines.md).
- When `gitleaks` is not installed, fall back to `git log --all -p | grep -iE` patterns — but note this is less reliable.
- The check skill only reports findings. Use the **uat-compliance-fix** skill to remediate.
