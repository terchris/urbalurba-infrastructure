# Investigate: Enonic Content Deployment

> **IMPLEMENTATION RULES:** Before implementing this plan, read and follow:
> - [WORKFLOW.md](../../WORKFLOW.md) - The implementation process
> - [PLANS.md](../../PLANS.md) - Plan structure and best practices

## Status: Backlog

**Goal**: Determine how content (data) moves between Enonic environments and whether it can be automated

**Last Updated**: 2026-03-09

**Related**:
- [INVESTIGATE-enonic-xp-deployment.md](INVESTIGATE-enonic-xp-deployment.md) — base Enonic XP platform deployment
- [INVESTIGATE-enonic-app-deployment-pipeline.md](INVESTIGATE-enonic-app-deployment-pipeline.md) — app (code) deployment pipeline

---

## Questions to Answer

1. How does content move between sandbox (dev) and UIS (test)?
2. What is the dependency between apps and content — what must be deployed first?
3. Can content exports be versioned in git for reproducibility?
4. What happens to content when an app's content types change?
5. Should the UIS CLI have content commands (`export-content`, `import-content`)?
6. Is there a way to seed a fresh Enonic instance with baseline content automatically?

---

## Background

### Terminology

- **Application (app)**: The code — a JAR file containing content type definitions, controllers, schemas, and logic. Deployed to the `$XP_HOME/deploy` directory.
- **Content**: The data — pages, articles, media, etc. Created and managed in Content Studio. Stored in Enonic's internal NoSQL repository.
- **Content type**: A schema defined by an app that describes the structure of a content item (e.g. "article", "blog-post"). Namespaced to the app: `com.example.myapp:article`.

### Content depends on apps

Every content item stores a type reference namespaced to its app:

```xml
<string name="type">com.example.myapp:article</string>
```

This means:
- **The app must be installed before content that uses its types can function.** Without the app, the raw data exists in storage but Content Studio cannot render, edit, or validate it.
- **Content types are the contract between app and content.** If you change the app name or rename content types, existing content becomes orphaned.

### Enonic's storage is schema-free

The underlying NoSQL store does not enforce schemas. Content type definitions are a presentation and validation layer on top of raw data. This means:
- **Adding fields**: Existing content works. New fields are empty until edited.
- **Removing fields**: Data persists in storage but is no longer visible in Content Studio.
- **Renaming fields**: Old field data persists but is invisible. Effectively a remove + add.
- **Changing validation rules**: Existing content may fail validation but is not destroyed.

Data is never deleted by schema changes — it just becomes invisible or invalid.

---

## Current State: How content moves between environments

Enonic has **no built-in content promotion pipeline** (dev → test → production). Content migration is always manual.

### Tools available

| Tool | What it does | Format | Scope |
|---|---|---|---|
| **Export/Import** (Data Toolbox or API) | Exports selected nodes and children as files | Human-readable XML + binaries | Partial — pick what to export |
| **Dump/Load** (`enonic dump` / `enonic load`) | Full repository transfer | Machine-readable | Everything — all repos, branches |
| **Snapshot/Restore** | Metadata + search index capture | Internal format | Backup, not migration |

### Export/Import (recommended for content migration)

- Creates a human-readable file structure in `$XP_HOME/data/export`
- Each content item is a directory with `node.xml` (data) and binary attachments
- Does NOT include version history, branches, or commits
- Can optionally preserve node IDs (`includeNodeIds: true`)
- Does NOT bundle app definitions — the app must already be installed on the target

### Dump/Load (full environment cloning)

- Machine-readable format of the entire repository
- Can include version history
- Useful for cloning a complete environment
- Heavier than export/import

---

## The developer workflow for content

### Current reality (manual process)

1. Developer creates content in their **local sandbox** (dev) using Content Studio on `localhost:8080`
2. When ready to promote to UIS (test):
   a. Export content from sandbox via Data Toolbox
   b. Download the export as a zip
   c. Upload to UIS Enonic instance at `enonic.localhost`
   d. Import the export via Data Toolbox
   e. Publish the imported content in Content Studio
3. The app must already be deployed on the UIS instance before importing content

### Deployment order matters

```
1. Deploy app (JAR) to target environment    ← app defines content types
2. Import content to target environment       ← content uses those types
3. Publish content in Content Studio          ← makes content live
```

Reversing steps 1 and 2 results in orphaned content that Content Studio cannot render.

---

## Options to investigate

### Can content exports live in git?

Content exports are file-based (XML + binary assets). It would be possible to:
- Commit content exports to a `content/` directory in the app repo
- Use a UIS CLI command or sidecar to import them after app deployment

**Pros:**
- Reproducible: any developer can spin up the same content
- Versioned: content changes are tracked alongside code
- Automated: import can happen as part of the deploy pipeline

**Cons:**
- Binary assets (images, PDFs) bloat the git repo
- Content IDs may conflict between environments
- Not a standard Enonic workflow — may have edge cases
- Merge conflicts in XML content files would be difficult to resolve

### Should the UIS CLI have content commands?

Possible commands:

```
./uis enonic export-content              # Export content from UIS Enonic to a local directory
./uis enonic import-content <path>       # Import content from a directory into UIS Enonic
./uis enonic seed-content <repo>         # Import baseline content from a git repo
```

Under the hood, these could use:
- `kubectl exec` into the Enonic pod + Enonic's export/import API
- Or the Data Toolbox REST endpoints if available

### Can the sidecar handle content too?

The app deployment sidecar monitors GitHub Releases for JAR files. Could it also handle content?

A content export could be published as a separate GitHub Release asset (e.g. `content-export.zip` alongside the app JAR). The sidecar would:
1. Download the content export
2. Place it in `$XP_HOME/data/export`
3. Trigger an import via the Enonic API

This couples content deployment to app deployment, which may or may not be desirable.

### Baseline content seeding

For a fresh Enonic instance, it would be useful to automatically seed baseline content (sample pages, default configuration, etc.). Options:
- Bundle content exports in the app repo
- Import as part of the setup playbook
- Provide a `./uis enonic seed-content` command

---

## Next Steps

- [ ] Determine if content-in-git is practical (test with a real Enonic export)
- [ ] Investigate Data Toolbox REST API for automated import/export
- [ ] Decide whether content commands belong in UIS CLI or are manual-only
- [ ] Decide whether content should be coupled to app deploys or managed separately
- [ ] Create PLAN if automation is feasible
