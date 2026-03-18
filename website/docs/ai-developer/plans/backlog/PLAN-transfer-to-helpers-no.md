# Plan: Transfer urbalurba-infrastructure to helpers-no

## Status: Backlog

**Goal**: Transfer this repo from `terchris/urbalurba-infrastructure` to `helpers-no/urbalurba-infrastructure` with zero downtime.

**Priority**: Medium

**Last Updated**: 2026-03-18

**Overall plan**: See `/Users/terje.christensen/learn/projects-2026/testing/github-helpers-no/INVESTIGATE-move-repos-to-helpers-no.md`

**Report back**: After completing each phase, update the overall plan's checklist in the file above. Mark the urbalurba-infrastructure line as complete when all phases are done.

---

## Prerequisites

- **PLAN-transfer-to-helpers-no** in devcontainer-toolbox must be complete (container image at `ghcr.io/helpers-no/`)
- Recommended: sovereignsky-site and dev-templates transfers complete first

**This repo transfers last** — it is the most complex and depends on devcontainer-toolbox.

---

## Problem

The repo lives under `terchris/urbalurba-infrastructure`. There are 85 references to `terchris` across 41 files. This repo also publishes its own container images (postgresql) to `ghcr.io/terchris/` and has GitHub Actions workflows that need updating.

---

## Phase 1: Create branch and fix references

### Tasks

- [x] 1.1 Create branch `move-to-helpers-no`
- [x] 1.2 Replace `ghcr.io/terchris/devcontainer-toolbox` → `ghcr.io/helpers-no/devcontainer-toolbox` in:
  - `.devcontainer/devcontainer.json`
- [x] 1.3 Replace `ghcr.io/terchris/urbalurba-` → `ghcr.io/helpers-no/urbalurba-` in own container images:
  - `containers/postgresql/build.sh`
  - `containers/postgresql/Dockerfile`
  - `manifests/042-database-postgresql-config.yaml`
- [x] 1.4 Update GitHub Actions workflow:
  - `.github/workflows/build-postgresql-container.yml` — update image registry path
- [x] 1.5 Replace `terchris/urbalurba-infrastructure` → `helpers-no/urbalurba-infrastructure` in install/CLI scripts:
  - `uis` script
  - `uis.ps1`
  - `website/static/install.sh`
  - `website/static/install.ps1`
  - `website/static/uis` and `website/static/uis.ps1`
  - `provision-host/uis/manage/uis-cli.sh`
  - `provision-host/uis/manage/uis-backstage-catalog.sh`
- [x] 1.6 Update docs/website references (~15 active doc files):
  - `website/docusaurus.config.ts`
  - `website/docs/` — about, index, getting-started, contributors, services, developing, reference, ai-developer/README
- [x] 1.7 `.gitignore` — `/terchris` entry kept (contains local secrets folder)
- [ ] 1.8 Commit all changes to branch (do NOT merge)

### Validation

User confirms all references are updated. Run: `grep -r "terchris" --include="*.sh" --include="*.ps1" --include="*.json" --include="*.yaml" --include="*.yml" --include="*.ts" .` should return zero critical hits.

---

## Phase 2: Transfer repo and update container images

### Tasks

- [ ] 2.1 Transfer repo on GitHub: Settings → Transfer → `helpers-no`
- [ ] 2.2 Verify GitHub redirect works
- [ ] 2.3 Check GH Actions has permissions to publish to `ghcr.io/helpers-no/` (postgresql image)
- [ ] 2.4 Merge `move-to-helpers-no` branch
- [ ] 2.5 Trigger container image builds — verify postgresql image publishes under `ghcr.io/helpers-no/`

### Validation

Repo is at `https://github.com/helpers-no/urbalurba-infrastructure`. Container images publish correctly.

---

## Phase 3: Re-enable GitHub Pages

### Tasks

- [ ] 3.1 Re-enable GitHub Pages in repo settings
- [ ] 3.2 Re-add custom domain: `dct.sovereignsky.no`
- [ ] 3.3 Verify site is live at https://dct.sovereignsky.no/

### Validation

User confirms website loads correctly.

---

## Phase 4: Update local clone and Kubernetes manifests

### Tasks

- [ ] 4.1 Update local git remote: `git remote set-url origin https://github.com/helpers-no/urbalurba-infrastructure.git`
- [ ] 4.2 If any running Kubernetes clusters reference `ghcr.io/terchris/urbalurba-` images, update the manifests and redeploy

### Validation

`git remote -v` shows `helpers-no/urbalurba-infrastructure`. Running services use new image paths.

---

## Acceptance Criteria

- [ ] Repo is at `https://github.com/helpers-no/urbalurba-infrastructure`
- [ ] Container images publish to `ghcr.io/helpers-no/`
- [ ] Website is live at `dct.sovereignsky.no`
- [ ] Install scripts (`uis`, `uis.ps1`) work from new location
- [ ] GitHub Actions workflows run successfully
- [ ] No remaining `terchris` references in critical scripts/manifests
- [ ] Old URL redirects work

---

## Files to Modify

**Container image refs:**
- `.devcontainer/devcontainer.json`
- `containers/postgresql/build.sh`
- `containers/postgresql/Dockerfile`
- `manifests/042-database-postgresql-config.yaml`

**GitHub Actions:**
- `.github/workflows/build-postgresql-container.yml`

**Install/CLI scripts:**
- `uis`
- `uis.ps1`
- `website/static/install.sh`
- `website/static/install.ps1`
- `provision-host/uis/manage/uis-cli.sh`
- `provision-host/uis/manage/uis-backstage-catalog.sh`

**Config/docs:**
- `.gitignore`
- `website/docusaurus.config.ts`
- ~25 website doc files
