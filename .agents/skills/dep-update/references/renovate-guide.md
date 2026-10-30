# Renovate CLI and Dependency Audit Guide

This guide details how to audit and update project dependencies across multiple ecosystems using Renovate CLI and native package managers.

## 1. Overview of Multi-Ecosystem Audits

Modern projects typically involve multiple dependency managers in a single repository:
- **npm / pnpm / yarn**: Application dependencies (`package.json`)
- **Docker**: Base image tags in `Dockerfile` (e.g., `FROM node:26-alpine`)
- **GitHub Actions**: Action versions in `.github/workflows/*.yml` (e.g., `actions/checkout@v4`)
- **Go Modules**: Go compiler version and libraries (`go.mod`)

Renovate CLI provides a single scanner capable of discovering, extracting, and querying release registries for all of these ecosystems simultaneously.

## 2. Renovate CLI Local Execution

Renovate can be executed on-demand without installing a persistent GitHub App or committing configuration files by using `--platform=local`.

### Essential CLI Flags and Environment Variables

| Variable / Flag | Purpose |
|---|---|
| `npx --yes renovate` | Runs Renovate on-demand without global installation |
| `--platform=local` | Scans the local working directory instead of connecting to a remote Git host |
| `--dry-run=lookup` | Queries package registries and logs available updates without modifying files |
| `RENOVATE_REQUIRE_CONFIG=ignored` | Allows running on repos that do not have `renovate.json` or config preset |
| `RENOVATE_ONBOARDING=false` | Disables automatic onboarding PR creation on local runs |
| `GITHUB_COM_TOKEN=$(gh auth token)` | Authenticates with GitHub API to prevent rate-limiting when querying GitHub Actions and release tags |
| `LOG_LEVEL=info` (or `debug`) | Controls log verbosity. Use `debug` to inspect exact candidate versions and release changelog URLs |

### Recommended One-Liner

```bash
GITHUB_COM_TOKEN="$(gh auth token 2>/dev/null || echo '')" \
RENOVATE_REQUIRE_CONFIG=ignored \
RENOVATE_ONBOARDING=false \
LOG_LEVEL=info \
npx --yes renovate --platform=local --dry-run=lookup
```

## 3. Interpreting Update Types

Renovate categorizes updates into three primary tiers:

1. **Patch / Minor Updates**:
   - Backward-compatible bug fixes and feature additions.
   - Example: `@types/node` 26.6.5 -> 26.6.6, `preact` 11.0.0 -> 11.1.0.
   - Low risk. Verify with test suite and type check.

2. **Major Updates**:
   - Potentially breaking changes in API, configuration, or runtime requirements.
   - Examples:
     - `node:22-alpine` -> `node:26-alpine` (Runtime engine jump)
     - `tailwindcss` 3.x -> 4.x (CSS configuration format changes)
     - `vite` 6.x -> 8.x (Plugin compatibility and bundling defaults)
   - High risk. Requires manual changelog review, migration guide check, and verification builds.

3. **Toolchain Version Alignment (Probe)**:
   - Ensuring `Dockerfile`, `go.mod`, and `package.json` engines match the host system and deployment target.
   - Always verify with `node -v`, `go version`, and `docker run --rm node:alpine node -v`.

## 4. Safe Upgrade Procedure

Follow this 5-step workflow whenever performing library updates:

1. **Audit First**: Run `./.agents/skills/dep-update/scripts/check-updates.sh <target-dir>` to inspect all ecosystems.
2. **Isolate Major from Minor**: Update minor/patch versions first, verify stability, and then evaluate major breaking changes separately.
3. **Run Verification Suite**:
   - TypeScript: `npm run typecheck`
   - Unit Tests: `npm test`
   - Application Build: `npm run build` or `make web-build`
   - Container Build: `docker build -t <image-name>:test .`
4. **Inspect Git Diff**: Run `git diff` to ensure `package.json` and `package-lock.json` are cleanly synchronized without extraneous changes.
5. **PR-Only Commit**: Submit via pull request and verify automated CI deployment workflows.
