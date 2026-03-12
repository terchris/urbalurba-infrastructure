# Investigate: Docs Markdown Generator Update Logic

> **IMPLEMENTATION RULES:** Before implementing this plan, read and follow:
> - [WORKFLOW.md](../../WORKFLOW.md) - The implementation process
> - [PLANS.md](../../PLANS.md) - Plan structure and best practices

## Status: Backlog

**Goal**: Add logic to `uis-docs-markdown.sh` to update metadata-driven sections of existing markdown pages without overwriting manually written content

**Last Updated**: 2026-03-11

**Related**:
- [INVESTIGATE-service-version-metadata.md](INVESTIGATE-service-version-metadata.md) — Version field is also missing from generator
- [INVESTIGATE-backstage.md](INVESTIGATE-backstage.md) — Adding new metadata fields (`SCRIPT_KIND`, `SCRIPT_TYPE`, `SCRIPT_OWNER`) to all service definitions. The docs generator should consume these too (e.g., display service type badge, ownership info).
- [PLAN-015-documentation-generation](../completed/PLAN-015-documentation-generation.md) — Original docs generator implementation

---

## Problem

`uis-docs-markdown.sh` has two modes: **skip** existing files (default) or **overwrite** them entirely (`--force`). There is no update/merge mode.

This means:
1. After initial generation, metadata changes in service scripts (e.g. `SCRIPT_DESCRIPTION`, `SCRIPT_REQUIRES`, `SCRIPT_NAMESPACE`) are never reflected in existing docs pages
2. Using `--force` destroys all manually written content (configuration tables, troubleshooting, secrets, key files)
3. Hand-written pages like `nextcloud.md` and `openmetadata.md` are completely disconnected from service metadata

### What should stay in sync with metadata

These sections are generated from service script fields and should update automatically:

| Section | Source fields |
|---------|-------------|
| Frontmatter (`title`, `sidebar_label`) | `SCRIPT_NAME` |
| Description line under `# Name` | `SCRIPT_DESCRIPTION` |
| Info table (Category, Deploy, Undeploy, Depends on, etc.) | `SCRIPT_CATEGORY`, `SCRIPT_ID`, `SCRIPT_REQUIRES`, `SCRIPT_HELM_CHART`, `SCRIPT_NAMESPACE` |
| "What It Does" paragraph | `SCRIPT_SUMMARY` |
| Deploy code block (prerequisites) | `SCRIPT_REQUIRES` |
| Verify code block (check command) | `SCRIPT_CHECK_COMMAND` |
| Learn More link | `SCRIPT_WEBSITE` |

### What should NOT be overwritten

These sections contain manually written content that varies per service:

- Configuration tables and details
- Secrets tables
- Key Files tables
- Troubleshooting sections
- Access URLs
- Service-specific notes (e.g. OnlyOffice integration, admin credentials)
- Any custom sections added by contributors

---

## Questions to Answer

1. What marker/delimiter strategy should separate auto-generated from manual sections?
2. Should the script update in-place or generate to a temp file for diff review?
3. How do we handle pages that were written entirely by hand (no markers)?
4. Should there be a `--update` mode alongside `--force` and default skip?
5. Is it acceptable to require a one-time migration to add markers to existing pages?

---

## Options

### Option A: Marker comments in markdown

Add HTML comments as markers around auto-generated sections:

```markdown
<!-- AUTO:INFO_TABLE -->
| | |
|---|---|
| **Category** | Management |
...
<!-- /AUTO:INFO_TABLE -->

## Configuration

(manual content here — never touched by generator)
```

The generator replaces content between matching `AUTO:` markers and leaves everything else untouched.

**Pros:**
- Clear, explicit boundaries
- HTML comments are invisible in rendered docs
- Easy to parse with sed/awk

**Cons:**
- Requires one-time migration to add markers to all existing pages
- Contributors must not delete markers
- Adds visual noise to raw markdown

### Option B: Section-based replacement

The generator identifies sections by heading (`## What It Does`, `## Deploy`, etc.) and replaces only the content of known auto-generated sections.

**Pros:**
- No markers needed
- Works with existing pages immediately

**Cons:**
- Fragile — relies on exact heading text
- Hard to distinguish auto-generated content from manual additions within a section
- Risk of overwriting manual content added under a "known" heading

### Option C: Frontmatter-only updates

Only update the YAML frontmatter and the info table. Leave all other sections untouched.

**Pros:**
- Minimal risk of overwriting manual content
- Simple to implement (just replace lines 1-N before first `## ` heading)

**Cons:**
- Doesn't update "What It Does", deploy prerequisites, or verify commands
- Partial solution

---

## Current State

- 27 service scripts exist in `provision-host/uis/services/`
- 27 corresponding `.md` pages exist in `website/docs/packages/`
- Some pages are auto-generated scaffolds (placeholder text), others are hand-written with full content
- Hand-written pages: `nextcloud.md`, `openmetadata.md`, `argocd.md`, `authentik.md`, `elasticsearch.md` (at minimum)
- No markers or conventions currently distinguish auto-generated from manual content

---

## Next Steps

- [ ] Decide on an approach
- [ ] Create PLAN to implement the chosen approach
- [ ] Migrate existing pages if markers are needed
