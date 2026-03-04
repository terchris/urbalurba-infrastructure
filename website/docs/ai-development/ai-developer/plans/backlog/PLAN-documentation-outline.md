# PLAN: Documentation Site Restructure — Add "Developing and Deploying" Section

> **IMPLEMENTATION RULES:** Before implementing this plan, read and follow:
> - [WORKFLOW.md](../../WORKFLOW.md) - The implementation process
> - [PLANS.md](../../PLANS.md) - Plan structure and best practices

## Status: Backlog

**Goal**: Add a "Developing and Deploying" section to the documentation site with 5 new pages covering the developer workflow from template to deployment, and restructure the sidebar to group infrastructure topics under "Advanced".

**Last Updated**: 2026-03-04

**Investigation**: [INVESTIGATE-documentation-outline](../backlog/INVESTIGATE-documentation-outline.md)

---

## Problem Summary

The documentation site has no section explaining how developers build and deploy their own applications. Developers need to know how to:
1. Create a project from a dev template
2. Understand the CI/CD pipeline (GitHub Actions → GHCR → ArgoCD → cluster)
3. Use `uis argocd register/remove/list` commands
4. Use the ArgoCD dashboard

Additionally, "Hosts & Platforms" and "Provision Host" are top-level sections that are infrastructure-level topics — they should be grouped under "Advanced" to keep the sidebar developer-focused.

---

## Phase 1: Create the 5 new pages

Create `website/docs/developing/` directory and write the 5 new pages.

### Tasks

- [ ] 1.1 Create `website/docs/developing/dev-templates.md` — How to use devcontainer-toolbox `dev-template.sh` to initialize a project from a template. Cover prerequisites, running the command, selecting a template, what gets created.
- [ ] 1.2 Create `website/docs/developing/template-catalog.md` — Table of current templates (name, language/framework, description) with links to individual READMEs in the `urbalurba-dev-templates` repo. Link to the repo for the full/latest list.
- [ ] 1.3 Create `website/docs/developing/argocd-pipeline.md` — Mermaid diagram and explanation of the full CI/CD pipeline: developer pushes → GitHub Actions builds image → pushes to GHCR → updates deployment.yaml tag → ArgoCD syncs → platform creates IngressRoute.
- [ ] 1.4 Create `website/docs/developing/argocd-commands.md` — How to use `uis argocd register <name> <repo-url>`, `remove <name>`, `list`, `verify`. Include examples, what each command does (namespace creation, IngressRoute, sync), common scenarios.
- [ ] 1.5 Create `website/docs/developing/argocd-dashboard.md` — How to access and use the ArgoCD web UI at `http://argocd.localhost`. Cover viewing app status, sync states, manual sync, deployment history, troubleshooting from the UI.

### Validation

User confirms page content is accurate and complete.

---

## Phase 2: Move files and restructure sidebar

Move `hosts/` and `provision-host/` under `advanced/`, update `sidebars.ts`, and fix all cross-links.

### Tasks

- [ ] 2.1 Create `website/docs/advanced/` directory
- [ ] 2.2 Move `website/docs/hosts/` → `website/docs/advanced/hosts/`
- [ ] 2.3 Move `website/docs/provision-host/` → `website/docs/advanced/provision-host/`
- [ ] 2.4 Update relative links in all 17 affected files:
  - `reference/documentation-index.md` (12 links)
  - `getting-started/infrastructure.md`
  - `contributors/rules/index.md`
  - `contributors/architecture/tools.md`
  - `ai-development/ai-developer/README.md`
  - `ai-development/ai-developer/plans/completed/INVESTIGATE-secrets-consolidation.md`
  - And remaining files found by grep
- [ ] 2.5 Update `website/sidebars.ts`:
  - Add "Developing and Deploying" category after "Packages" with the 5 new pages
  - Create "Advanced" category containing the moved "Hosts & Platforms" and "Provision Host" items
  - Add `reference/factory-reset` to the "Reference" category
  - Remove old top-level "Hosts & Platforms" and "Provision Host" entries

### Validation

```bash
cd website && npm run build
```

Docusaurus build succeeds with no broken link warnings. User confirms sidebar structure looks correct.

---

## Phase 3: Verify and commit

### Tasks

- [ ] 3.1 Verify all 5 new pages render correctly in the sidebar
- [ ] 3.2 Verify "Advanced" section contains Hosts & Platforms and Provision Host
- [ ] 3.3 Verify "Reference" section includes Factory Reset
- [ ] 3.4 Verify no broken links in the build output
- [ ] 3.5 Commit and push

### Validation

User confirms the site looks correct.

---

## Acceptance Criteria

- [ ] 5 new pages exist in `website/docs/developing/`
- [ ] "Developing and Deploying" section appears in sidebar after "Packages"
- [ ] "Hosts & Platforms" and "Provision Host" appear under "Advanced"
- [ ] "Factory Reset" appears in the "Reference" section
- [ ] `npm run build` succeeds with no broken link errors
- [ ] ArgoCD pipeline page has a Mermaid diagram showing the full CI/CD flow
- [ ] Template catalog lists all 7 current templates with links to the repo
- [ ] No cross-link breakage — all relative links updated

---

## Files to Modify

### New files

| File | Content |
|------|---------|
| `website/docs/developing/dev-templates.md` | Dev template usage guide |
| `website/docs/developing/template-catalog.md` | Template catalog with repo links |
| `website/docs/developing/argocd-pipeline.md` | CI/CD pipeline with Mermaid diagram |
| `website/docs/developing/argocd-commands.md` | UIS ArgoCD CLI usage guide |
| `website/docs/developing/argocd-dashboard.md` | ArgoCD web UI guide |

### Moved directories

| From | To |
|------|----|
| `website/docs/hosts/` | `website/docs/advanced/hosts/` |
| `website/docs/provision-host/` | `website/docs/advanced/provision-host/` |

### Modified files

| File | Change |
|------|--------|
| `website/sidebars.ts` | Add "Developing and Deploying", create "Advanced", add factory-reset to Reference |
| 17 files with cross-links | Update relative paths from `../hosts/` to `../advanced/hosts/` etc. |
