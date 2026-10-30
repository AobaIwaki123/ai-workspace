---
name: dep-update
description: Audits, checks, and guides dependency and toolchain updates across multi-language repositories (NPM, Dockerfile, Go modules, GitHub Actions) using Renovate CLI dry-run and native package managers. Use this skill when the user asks to check for outdated libraries, update dependencies, run renovate cli, audit toolchain versions, or perform library upgrades.
---

# Dependency and Toolchain Update Skill (dep-update)

Audits, updates, and verifies dependencies across multiple ecosystems (Node/NPM, Dockerfile base images, Go modules, GitHub Actions) using Renovate CLI dry-run lookup and native package tools.

## 1. Quick Audit Execution

To run an automated audit across all ecosystems in a target project:

```bash
# Audit specific repository or workspace directory
./.agents/skills/dep-update/scripts/check-updates.sh <path-to-target-repo>

# Or run directly on current repository
./.agents/skills/dep-update/scripts/check-updates.sh .
```

The script automatically executes:
1. **Toolchain Probe**: Extracts runtime versions for Node, npm, Go, and latest Docker Alpine Node.
2. **Renovate Multi-Ecosystem Scan**: Executes Renovate CLI in local dry-run lookup mode (`--platform=local --dry-run=lookup`), scanning Dockerfile, GitHub Actions, Go modules, and NPM package files.
3. **Native Package Audits**: Runs `npm outdated` and `go list -u -m all` for localized inspection.

## 2. Renovate CLI One-Liner

When running Renovate CLI manually without script wrappers:

```bash
GITHUB_COM_TOKEN="$(gh auth token 2>/dev/null || echo '')" \
RENOVATE_REQUIRE_CONFIG=ignored \
RENOVATE_ONBOARDING=false \
LOG_LEVEL=info \
npx --yes renovate --platform=local --dry-run=lookup
```

For verbose logging including candidate versions and changelog URLs, set `LOG_LEVEL=debug`.

## 3. Phased Update Protocol

Follow this 4-phase sequence to prevent breaking changes:

### Phase 1: Toolchain Alignment
- Synchronize `Dockerfile` base images and `package.json` engines with the actual runtime environment (`node -v`, `go version`).
- Never guess or hardcode outdated major versions (e.g. `node:22-alpine` when host is on Node 26).

### Phase 2: Patch and Minor Updates
- Apply non-breaking patch and minor versions first:
  ```bash
  npm update
  # Or target specific packages:
  npm install @types/node@latest lucide@latest
  ```

### Phase 3: Major Updates Evaluation
- For major version jumps (e.g., Tailwind CSS 3 -> 4, Vite 6 -> 8, TypeScript 5 -> 7):
  - Check breaking change changelogs and framework migration guides.
  - Test in an isolated branch.
  - Review syntax deprecations (e.g., SVG type imports in Preact 10 vs 11).

### Phase 4: Local Full Verification
Always execute all local build and test targets before committing:
```bash
# 1. Type check
npm run typecheck

# 2. Automated test suite
npm test

# 3. Application bundle build
make web-build  # or npm run build

# 4. Multi-stage container build
docker build -t <image-name>:test .
```

## 4. References

- Detailed CLI options, local dry-run flags, and troubleshooting: [references/renovate-guide.md](references/renovate-guide.md)
