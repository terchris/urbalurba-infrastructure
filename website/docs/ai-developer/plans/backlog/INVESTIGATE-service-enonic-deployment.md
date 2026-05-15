# Investigate: Enonic Deployment (apps + content)

> **IMPLEMENTATION RULES:** Before implementing this plan, read and follow:
> - [WORKFLOW.md](../../WORKFLOW.md) - The implementation process
> - [PLANS.md](../../PLANS.md) - Plan structure and best practices

## Status: Backlog

**Goal**: Design how artefacts get into the Enonic XP instance running in UIS. Two related artefact types:

1. **Apps** (JAR files — code) — pipeline design well-defined; chosen approach is the sidecar container pattern (see "Apps deployment" sections below).
2. **Content** (data — pages, articles, media) — open question; multiple options under evaluation (see "Content deployment" section near the bottom).

Apps and content are tightly coupled at deploy time: content stores type references namespaced to its parent app, so apps must be installed before content that references them can be rendered. Hence one investigation covering both, with the option to ship them as separate PLANs once the content side reaches a decision.

**Last Updated**: 2026-05-15 (merged from `INVESTIGATE-service-enonic-content-deployment` on this date)

**Related**: [INVESTIGATE-enonic-xp-deployment.md](../completed/INVESTIGATE-enonic-xp-deployment.md) — covers the base Enonic XP platform deployment

---

## Questions to Answer

1. How should the sidecar container be designed? (polling logic, error handling, multi-app support)
2. What UIS CLI commands are needed and how do they map to the sidecar's ConfigMap?
3. What does the GitHub Actions workflow look like for Enonic app repos?
4. How does rollback work?
5. How does the sidecar handle private GitHub repos?

---

## Background

### Why this is needed

Enonic apps are JAR files deployed TO a running XP instance. This is fundamentally different from Docker container apps where ArgoCD deploys new container images. The XP platform runs as a single long-lived pod — apps are installed into it, not deployed as separate containers.

### Why ArgoCD doesn't fit

The UIS ArgoCD pipeline builds Docker images and deploys them as K8s pods. Enonic apps need a different approach because:
- Apps are JARs, not container images
- Apps are installed into a running XP instance, not deployed as separate pods
- Enonic supports hot-installing apps without restart via the `$XP_HOME/deploy` directory

### The CI/CD reachability problem

Enonic's standard CI/CD uses the management API on port 4848. This requires the pipeline agent to have network access to the XP instance. This doesn't work when:
- **Enterprise Azure**: XP behind a VNet firewall, hosted CI/CD agents outside the VNet
- **Local UIS**: XP in k3s on a laptop, GitHub Actions in the cloud

The solution in both cases is a **pull-based approach**: the pipeline builds and publishes the artifact, and something on the XP side pulls and deploys it.

### All four ways to install apps on Enonic XP

| Method | How | Typical use |
|---|---|---|
| **Admin Console** | Web UI upload (drag-and-drop) at port 8080 | Manual deployment |
| **Management API** | CLI or HTTP to port 4848 | CI/CD pipelines (requires network access) |
| **File system** | Drop JAR in `$XP_HOME/deploy` directory, XP auto-detects and installs | Local dev, automated pulls |
| **Bundled** | Package app with XP runtime | Microservice-style deployments |

We use the **file system** method: the sidecar downloads JARs and places them in `$XP_HOME/deploy`.

---

## Chosen Approach: Sidecar Container

A sidecar container runs alongside Enonic XP in the same pod, sharing the `$XP_HOME/deploy` volume. It monitors GitHub Releases and deploys new JARs automatically.

### Pipeline flow

```
Developer works on feature branch → creates PR → merges to main
→ GitHub Actions builds JAR → publishes to GitHub Releases
→ sidecar polls releases → downloads JAR → Enonic hot-installs (no restart)
```

### Why sidecar (not init container + ArgoCD)

An alternative approach uses ArgoCD + an init container: ArgoCD detects a manifest change, triggers a pod rollout, and an init container downloads the JAR during startup. This was rejected because:
- It restarts Enonic on every app deploy (downtime, loss of in-memory state)
- It requires committing manifest changes back to the repo from GitHub Actions
- It has more moving parts (ArgoCD registration + init container + manifest commit + `[ci-skip]` pattern)

The sidecar is simpler: no ArgoCD, no manifest commit-back, no pod restart.

---

## Sidecar Design

### How it works

1. The sidecar reads a ConfigMap listing GitHub repos to monitor
2. For each repo, it periodically polls the GitHub Releases API
3. When it finds a newer release than what is currently deployed, it downloads the JAR asset
4. Places it in the shared `$XP_HOME/deploy` volume
5. Enonic XP auto-detects and hot-installs the app

### ConfigMap structure

The ConfigMap lists registered apps. Each entry has a repo URL and the currently deployed version:

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: enonic-app-registry
  namespace: enonic
data:
  apps.json: |
    {
      "apps": [
        {
          "repo": "myorg/my-enonic-app",
          "currentVersion": "v1a2b3c-20260306120000",
          "jarFile": "my-enonic-app-1.0.0.jar"
        }
      ]
    }
```

### Polling logic

```
loop:
  for each app in ConfigMap:
    GET https://api.github.com/repos/{owner}/{repo}/releases/latest
    if release.tag != app.currentVersion:
      download JAR asset from release
      place in $XP_HOME/deploy/
      remove old JAR from $XP_HOME/deploy/ (if different filename)
      update ConfigMap with new version
  sleep POLL_INTERVAL (e.g. 60 seconds)
```

### Container specification

The sidecar is a lightweight container — a shell script with `curl`, `jq`, and `sleep`. It could use a minimal image like `alpine` or `busybox` with `curl` added.

### Open questions

- **Private repos**: GitHub Releases API requires authentication for private repos. The sidecar would need a GitHub token (stored as a K8s Secret). Public repos work without authentication but have lower rate limits (60 req/hour vs 5000 req/hour).
- **Multiple JAR assets per release**: If a release has multiple JAR files, how does the sidecar know which one to download? Convention: download all `.jar` assets? Or require a specific naming pattern?
- **Health/status reporting**: Should the sidecar expose a status endpoint or log to stdout? Stdout is simplest (visible via `kubectl logs`).

---

## UIS CLI Commands

Analogous to the existing ArgoCD commands:

```
./uis argocd register <github-repo>    # Register Docker app with ArgoCD
./uis argocd unregister <app-name>     # Remove app
./uis argocd list                      # List registered apps
```

Enonic equivalents:

```
./uis enonic deploy-app <github-repo>  # Register repo — sidecar starts monitoring its releases
./uis enonic remove-app <app-name>     # Unregister — sidecar stops monitoring, removes JAR
./uis enonic list-apps                 # List monitored repos and installed versions
```

### What `deploy-app` does under the hood

1. Validates the GitHub repo exists and has releases
2. Updates the `enonic-app-registry` ConfigMap with the new repo
3. Optionally downloads and deploys the latest release immediately (so the developer doesn't have to wait for the next poll cycle)

### What `remove-app` does

1. Removes the repo from the ConfigMap
2. Deletes the JAR from `$XP_HOME/deploy` (via `kubectl exec`)
3. Enonic auto-detects the removal and uninstalls the app

---

## GitHub Actions Workflow

Since the sidecar polls GitHub Releases directly, the workflow only needs to build and publish. No manifest commit-back, no `[ci-skip]` pattern, no `paths-ignore`.

### Enonic's official build action

`enonic/action-app-build` does three things:

```yaml
steps:
  - uses: actions/setup-java@v4
    with:
      distribution: temurin
      java-version: 11
  - uses: gradle/actions/setup-gradle@v4
  - run: ./gradlew build -Pcom.enonic.xp.app.production=true
```

### Proposed workflow for Enonic app repos

```yaml
# .github/workflows/enonic-build-and-publish.yaml
name: Build and Publish Enonic App
on:
  push:
    branches: [main]

permissions:
  contents: write

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - uses: actions/setup-java@v4
        with:
          distribution: temurin
          java-version: 11

      - uses: gradle/actions/setup-gradle@v4

      - name: Build Enonic app
        run: ./gradlew build -Pcom.enonic.xp.app.production=true

      - name: Generate unique tag
        run: |
          TIMESTAMP=$(date +%Y%m%d%H%M%S)
          echo "APP_VERSION=${GITHUB_SHA::7}-${TIMESTAMP}" >> $GITHUB_ENV
          echo "JAR_FILE=$(ls build/libs/*.jar | head -1)" >> $GITHUB_ENV

      - name: Create GitHub Release
        uses: softprops/action-gh-release@v2
        with:
          tag_name: v${{ env.APP_VERSION }}
          files: ${{ env.JAR_FILE }}
          generate_release_notes: true
```

This is simpler than the existing UIS `urbalurba-build-and-push.yaml` workflow because there's no manifest to update — the sidecar polls GitHub Releases directly.

---

## Rollback

To roll back to a previous version:

1. Delete the bad GitHub Release (or mark it as draft/pre-release)
2. The sidecar's next poll sees a different latest release
3. It downloads the previous JAR and places it in `$XP_HOME/deploy`
4. Enonic hot-installs the old version

For comparison, ArgoCD rollback for Docker container apps works by reverting a git commit — which is conceptually the same thing (changing what the "latest" artifact is).

---

## Proposed Files

| Piece | File | Purpose |
|-------|------|---------|
| UIS CLI commands | `provision-host/uis/lib/enonic.sh` | `deploy-app`, `remove-app`, `list-apps` |
| Sidecar script | `provision-host/uis/tools/enonic-app-watcher.sh` | Polls GitHub Releases, downloads JARs |
| GitHub Actions template | `provision-host/uis/templates/enonic-build-and-publish.yaml` | Workflow for Enonic app repos |

The sidecar is included in the Enonic StatefulSet defined in the base platform investigation (`manifests/085-enonic-statefulset.yaml`).

---

## Next Steps (apps)

- [ ] Decide on open questions (private repos, multiple JARs, status reporting)
- [ ] Create PLAN for the base Enonic XP platform deployment (from INVESTIGATE-enonic-xp-deployment.md)
- [ ] Create PLAN for the app deployment pipeline (from this investigation)

---

# Content deployment

The sections below were merged in from `INVESTIGATE-service-enonic-content-deployment.md` on 2026-05-15. Content deployment is at an earlier decision stage than apps — multiple options still open.

## Content deployment — Questions to Answer

1. How does content move between sandbox (dev) and UIS (test)?
2. What is the dependency between apps and content — what must be deployed first?
3. Can content exports be versioned in git for reproducibility?
4. What happens to content when an app's content types change?
5. Should the UIS CLI have content commands (`export-content`, `import-content`)?
6. Is there a way to seed a fresh Enonic instance with baseline content automatically?

## Content deployment — Background

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

## Content deployment — Current state

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

### Current developer workflow (manual)

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

## Content deployment — Options

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

The app deployment sidecar (designed in the "Apps deployment" section above) monitors GitHub Releases for JAR files. Could it also handle content?

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

## Next Steps (content)

- [ ] Determine if content-in-git is practical (test with a real Enonic export)
- [ ] Investigate Data Toolbox REST API for automated import/export
- [ ] Decide whether content commands belong in UIS CLI or are manual-only
- [ ] Decide whether content should be coupled to app deploys or managed separately
- [ ] Create PLAN if automation is feasible
