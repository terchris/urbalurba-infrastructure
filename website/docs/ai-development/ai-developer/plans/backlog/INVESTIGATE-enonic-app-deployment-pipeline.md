# Investigate: Enonic App Deployment Pipeline

> **IMPLEMENTATION RULES:** Before implementing this plan, read and follow:
> - [WORKFLOW.md](../../WORKFLOW.md) - The implementation process
> - [PLANS.md](../../PLANS.md) - Plan structure and best practices

## Status: Backlog

**Goal**: Design and implement a pull-based pipeline for deploying Enonic apps (JAR files) into the Enonic XP instance running in UIS

**Last Updated**: 2026-03-06

**Related**: [INVESTIGATE-enonic-xp-deployment.md](INVESTIGATE-enonic-xp-deployment.md) — covers the base Enonic XP platform deployment

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

## Next Steps

- [ ] Decide on open questions (private repos, multiple JARs, status reporting)
- [ ] Create PLAN for the base Enonic XP platform deployment (from INVESTIGATE-enonic-xp-deployment.md)
- [ ] Create PLAN for the app deployment pipeline (from this investigation)
