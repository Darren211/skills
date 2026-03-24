---
name: uat-compliance-fix
description: >
  Fix UAT/production codebase compliance violations per SEC-STD-001 guidelines.
  Use when asked to: fix, remediate, resolve, repair compliance issues, generate
  missing security files, clean up credentials, fix .gitignore/.dockerignore,
  harden Dockerfile, set safe config defaults, remove hardcoded private IPs,
  or bring a repository into compliance. Covers Exchange platform services (Go, Java/Spring Boot, Flutter).
---

# UAT Codebase Compliance Fix

Remediate compliance violations found by audit against SEC-STD-001.
Full specification: [references/compliance-guidelines.md](references/compliance-guidelines.md)

## Workflow

### 1. Assess current state

If no audit report is provided, first run the **uat-compliance-check** skill or ask the user for findings.
Determine the project type: **Go** (`go.mod`), **Java** (`pom.xml`), or **Flutter** (`pubspec.yaml`).

### 2. Fix in priority order

Always fix Critical → High → Medium → Low. **Never skip credential rotation for Critical issues.**

---

## Fix Procedures by Category

### F1: Remove credential files from tracking (Critical)

```bash
# Remove from git tracking (keeps local file)
git rm --cached .env data/private/private.toml .netrc credentials.json
git commit -m "sec: remove credential files from version control"
```

Then ensure `.gitignore` covers them (see F3).

**If credentials were committed:** they are considered leaked.
1. **Rotate all exposed credentials immediately** (DB passwords, API keys, tokens)
2. Clean git history:
   ```bash
   # Option A: BFG (recommended)
   bfg --delete-files "private.toml" --no-blob-protection
   bfg --replace-text passwords.txt --no-blob-protection
   git reflog expire --expire=now --all && git gc --prune=now --aggressive
   
   # Option B: git filter-repo
   git filter-repo --path data/private/ --invert-paths
   ```
3. Force push and notify team to re-clone
4. Verify: `gitleaks detect --source . --log-opts="--all"`

⚠️ **Always confirm with user before force-pushing or history rewriting.**

### F2: Replace hardcoded IPs (High)

Find and replace hardcoded private IPs with environment variable references:

| Context | Pattern to find | Replace with |
|---------|----------------|--------------|
| Config `.toml` | `"10.x.x.x:port"` | `"${ENV_VAR_NAME}"` |
| Makefile | `-address=http://10.x.x.x:4646` | `-address=$(NOMAD_ADDR)` |
| CI yaml | hardcoded IP endpoints | `$CI_VARIABLE` references |

When replacing in config templates, create a `config.example.toml` or `.env.example` documenting required variables.

### F3: Fix .gitignore (High)

Use the appropriate template from [assets/templates/](assets/templates/).
Template files available:
- `gitignore-go` — Go projects
- `gitignore-java` — Java/Spring Boot projects
- `gitignore-flutter` — Flutter projects

**Critical rules:**
- MUST include all L1 patterns (`.env`, `.env.*`, `!.env.example`, `.netrc`, `*.pem`, `*.key`, etc.)
- MUST NOT ignore test files (`*_test.go`, `*Test.java`, `*_test.dart`)
- MUST NOT ignore `go.sum`, `Dockerfile`

If a `.gitignore` exists, merge missing rules rather than overwriting (preserve project-specific entries).

### F4: Create/fix .dockerignore (Medium)

Use [assets/templates/dockerignore](assets/templates/dockerignore) as baseline.
Must exclude: `.git`, `.env`, `*.pem`, `*.key`, `.netrc`, `data/private/`, `*.md`, IDE dirs, test files.

### F5: Fix Dockerfile (High)

Apply these fixes to the existing Dockerfile:

1. **Remove `COPY .netrc`** → replace with BuildKit secret mount:
   ```dockerfile
   RUN --mount=type=secret,id=netrc \
       if [ -f /run/secrets/netrc ]; then \
           cp /run/secrets/netrc /home/builder/.netrc && \
           chown builder:builder /home/builder/.netrc && \
           chmod 600 /home/builder/.netrc; \
       fi
   ```

2. **Move `USER` before `ENTRYPOINT`:**
   ```dockerfile
   USER exchange
   ENTRYPOINT ["./main"]
   ```

3. **Remove `COPY data/private/`** lines.

### F6: Set safe config defaults (High)

In `data/config/config.toml` or `src/main/resources/application.yml`:

```toml
# Required safe defaults
[debug]
debug = false
gin_debug = false
request_log = false
response_log = false
db_log = false
log_min_level = "warn"
swagger = false
```

For YAML configs:
```yaml
debug:
  enabled: false
logging:
  level: WARN
swagger:
  enabled: false
```

### F7: Create missing required files (Medium/Low)

Generate missing files using templates from [assets/templates/](assets/templates/):

| File | Template | Priority |
|------|----------|----------|
| `SECURITY.md` | [assets/templates/SECURITY.md](assets/templates/SECURITY.md) | Medium |
| `CHANGELOG.md` | [assets/templates/CHANGELOG.md](assets/templates/CHANGELOG.md) | Low |
| `README.md` | Generate project-specific | Low |
| `.gitleaks.toml` | [assets/templates/gitleaks.toml](assets/templates/gitleaks.toml) | Medium |
| `.pre-commit-config.yaml` | [assets/templates/pre-commit-config.yaml](assets/templates/pre-commit-config.yaml) | Medium |
| `.env.example` or `config.example.toml` | Derive from actual config, with empty/placeholder values | Medium |

### F8: Ensure test files are tracked (High)

If `.gitignore` contains test patterns, remove them:
```bash
# Remove test ignore rules from .gitignore
sed -i '/_test\.\(go\|dart\)/d' .gitignore
sed -i '/Test\.java/d' .gitignore
```

If test files exist but are untracked:
```bash
git add **/*_test.go **/*Test.java **/test/ 2>/dev/null
```

### F9: Remove audit reports from repo (Medium)

```bash
git rm --cached *_Code_Review_Report.* 2>/dev/null
# Ensure .gitignore covers them
echo '*_Code_Review_Report.*' >> .gitignore
```

### F10: Add CI security scanning (Medium)

For GitLab CI, add to `.gitlab-ci.yml`:
```yaml
gitleaks-scan:
  stage: test
  image: zricethezav/gitleaks:latest
  script:
    - gitleaks detect --source . --verbose
  allow_failure: false
```

---

## Post-fix verification

After all fixes, verify compliance:

```bash
# Re-run the audit checks
git ls-files | grep -iE '\.env$|\.env\.|\.netrc|\.pem$|\.key$|data/private'
# Should return empty

grep -rnE '(debug|gin_debug)\s*[=:]\s*(true|"true")' data/config/ src/main/resources/ 2>/dev/null
# Should return empty

grep '_test\.' .gitignore
# Should return empty
```

## Commit convention

Use prefixed commit messages for audit trail:

- `sec: remove credential files from tracking`
- `sec: replace hardcoded private IPs with env variables`
- `sec: fix Dockerfile — BuildKit secrets, non-root user`
- `sec: set safe config defaults (debug=false)`
- `chore: add .dockerignore, .gitleaks.toml, pre-commit hooks`
- `docs: add SECURITY.md, CHANGELOG.md`

## Safety rules

- **Always confirm before:** force push, history rewriting, credential rotation
- **Never delete** credential files from disk — only untrack from git (`git rm --cached`)
- **Never commit** real credentials into template/example files
- **Create backups** of modified config files before overwriting
- If unsure about a fix's impact, ask the user
