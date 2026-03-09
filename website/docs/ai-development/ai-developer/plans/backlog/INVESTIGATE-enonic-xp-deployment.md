# Investigate: Enonic XP CMS Deployment

> **IMPLEMENTATION RULES:** Before implementing this plan, read and follow:
> - [WORKFLOW.md](../../WORKFLOW.md) - The implementation process
> - [PLANS.md](../../PLANS.md) - Plan structure and best practices

## Status: Backlog

**Goal**: Determine the best approach for deploying Enonic XP as a UIS platform service

**Last Updated**: 2026-03-06

---

## Questions to Answer

1. Should we use the Enonic XP Kubernetes Operator or a simpler Docker/Helm deployment? → **Option B (Plain Docker)**
2. What category and manifest number range should Enonic use? → **INTEGRATION, 085**
3. What storage architecture is needed? → **Standard PVCs via cluster storage class, same as all other services**
4. Does Enonic XP's embedded Elasticsearch conflict with existing ES? → **No, embedded ES is internal to the pod**
5. What does the developer miss without the operator? → **Nothing relevant — see below**
6. What hostname for Traefik routing? → **`enonic.localhost`**

---

## Current State

- No CMS service exists in UIS currently
- Enonic XP is not deployed anywhere in the cluster
- The infrastructure has all prerequisites: Kubernetes (k3s via Rancher Desktop), Helm, Traefik, storage classes, Ansible automation

## Environment

- **Platform**: UIS — a local development environment running on developer laptops
- **Kubernetes**: k3s via Rancher Desktop (resource-constrained)
- **Storage**: `rancher.io/local-path` provisioner — services request storage via standard PVCs
- **Ingress**: Traefik, hostname-based routing (e.g. `grafana.localhost`, `whoami.localhost`)
- **Deployment pattern**: Helm charts + Ansible playbooks, manifests in `manifests/` directory

---

## Background Research

### What is Enonic XP?

Enonic XP is a Java/GraalVM-based headless CMS platform. It's used by major Norwegian organizations (NAV, Gjensidige, Helsedirektoratet). It provides Content Studio (editorial UI), headless APIs, and a composable architecture.

### Docker Image

- **Image**: `enonic/xp` on Docker Hub (based on `enonic/graalvm`)
- **Ports**: 8080 (server), 4848 (management), 2609 (metrics), 5701 (Hazelcast), 9200/9300 (Elasticsearch)
- **Environment**: `XP_OPTS` for JVM params, heap should be ~30% of container memory
- **Persistent volumes needed**: A single PVC for `$XP_HOME` covers all data (config, blobstore, index, deploy, snapshots). Standard cluster storage via PVC, same as all other UIS services.

### Kubernetes Deployment Options

#### Option A: Enonic XP Kubernetes Operator

The official operator (v1.0.0, released Jan 2025) provides:
- Custom resources: `Xp7Deployment`, `Xp7Config`, `Xp7App`
- Manages single-node and clustered deployments
- Built-in storage management (shared + private disks)
- VHost management via ingress annotations
- App installation via CRD
- Helm-based installation to `kube-system` namespace

**Requirements**: Kubernetes 1.27+, Helm, SSD-backed default storage class, NFS shared storage class (NFS not available on k3s/Rancher Desktop)

**Helm repo**: `https://repo.enonic.com/` (browse at `https://repo.enonic.com/#browse/browse:helm:xp-operator`)

#### Option B: Plain Docker Image with Custom Helm Chart / Manifests

Deploy `enonic/xp` directly using standard Kubernetes manifests or a custom Helm values file:
- StatefulSet with persistent volumes
- Service + IngressRoute
- ConfigMaps for XP configuration

---

## Options

### Option A: Enonic XP Kubernetes Operator

**Pros:**
- Official, supported deployment method for Kubernetes
- Handles complex storage topology (shared vs private)
- Custom resources for app management (`Xp7App`) and config (`Xp7Config`)
- Built-in support for clustering if needed later
- VHost management integrated with ingress annotations

**Cons:**
- Installs a cluster-wide operator in `kube-system` namespace
- Adds CRDs to the cluster (more moving parts)
- Requires NFS storage class for shared volumes
- Heavier footprint for a single-node dev setup
- Less transparent — operator manages resources behind the scenes

### Option B: Plain Docker Deployment (StatefulSet + Manifests)

**Pros:**
- Simpler — follows the same pattern as other UIS services
- No CRDs or operator overhead
- Full visibility into all Kubernetes resources
- Lighter footprint for local development
- Easier to debug and troubleshoot

**Cons:**
- No built-in app management CRD (`Xp7App`)
- Clustering would require manual configuration (not needed for local dev)

---

## What does the developer miss without the operator?

The operator adds three things relevant to a single-node setup:

1. **`Xp7App` CRD** — Declaratively install Enonic apps by specifying a URL + checksum in YAML. Without it, apps are installed through the XP admin UI, Enonic CLI, or by placing JARs in the deploy directory.
2. **`Xp7Config` CRD** — Push config changes to XP declaratively. Without it, use ConfigMaps mounted as volumes (standard Kubernetes approach).
3. **VHost annotations on Ingress** — Configure XP virtual hosts via ingress annotations instead of XP config files.

Everything else the operator provides (clustering, node groups, shared/private storage topology, rolling updates) is irrelevant for a single-node dev setup.

**The developer workflow does not depend on the operator.** The operator's CRDs are operational conveniences for managing production clusters.

---

## Enonic Developer Workflow

The standard Enonic development workflow uses **two XP instances** with different roles:

### 1. Local Sandbox (for coding)

The Enonic CLI manages a local XP instance called a "sandbox":

```bash
npm install -g @enonic/cli          # Install CLI
enonic sandbox create mysandbox -t essentials -f  # Create & start local XP
enonic project create               # Scaffold a new app from a starter template
enonic dev                          # Hot-reload development mode
```

The sandbox runs on `localhost:8080`. The developer codes, iterates, and tests here with hot reload. This is entirely local — no Kubernetes involved.

### 2. K8s XP Instance (for deployment and content management)

The XP instance in Kubernetes (at `http://enonic.localhost`) serves as the shared environment where:

- **Apps are deployed**: Developer builds a `.jar` file (`enonic project build`), then deploys it via the Admin Console (drag-and-drop upload at `enonic.localhost`) or the Management API (port 4848, used in CI/CD pipelines)
- **Content is managed**: Editors use Content Studio at `enonic.localhost` to create and manage content
- **APIs are served**: Headless GraphQL/REST APIs serve content to frontend applications

### Summary

| Environment | Purpose | Access |
|---|---|---|
| Local sandbox | Coding, hot-reload, iteration | `localhost:8080` (CLI managed) |
| K8s XP instance | App deployment, content management, API serving | `enonic.localhost` (Traefik routed) |

---

## Content and App Deployment

Enonic has two separate things that need to be deployed: **apps** (code) and **content** (data).

### App deployment (code)

App deployment is covered in a separate investigation: **[INVESTIGATE-enonic-app-deployment-pipeline.md](INVESTIGATE-enonic-app-deployment-pipeline.md)**

Summary of the chosen approach: a sidecar container in the Enonic pod monitors GitHub Releases. When a developer merges to main, GitHub Actions builds the JAR and publishes it as a GitHub Release. The sidecar polls for new releases, downloads the JAR, and places it in `$XP_HOME/deploy`. Enonic hot-installs the app without restart. UIS CLI commands (`./uis enonic deploy-app`, `remove-app`, `list-apps`) manage which repos the sidecar monitors.

### Content deployment (data)

Content deployment is covered in a separate investigation: **[INVESTIGATE-enonic-content-deployment.md](INVESTIGATE-enonic-content-deployment.md)**

Key finding: content depends on apps. The app (with its content type definitions) must be deployed **before** content can be imported. Content items store a type reference namespaced to the app (e.g. `com.example.myapp:article`), so without the app installed, content is non-functional.

### Environments and roles

| Environment | Role | Where | Access |
|---|---|---|---|
| **Local sandbox** | Dev environment (per developer) | Developer's machine, CLI-managed | `localhost:8080` |
| **Enonic XP in UIS** | Test environment (shared) | k3s on developer's laptop | `enonic.localhost` |
| **Hosted Enonic** | Staging/production | Azure, Enonic Cloud, etc. | Custom domain |

### Summary: what gets deployed and how

| What | Format | Deploy method (production) | Deploy method (local UIS) |
|---|---|---|---|
| **XP platform** | Docker image `enonic/xp` | K8s deployment (Helm/manifests) | Same — Ansible playbook deploys to k3s |
| **Apps (code)** | JAR file | CI/CD agent on same network → management API (port 4848) | Sidecar pull pipeline — see [INVESTIGATE-enonic-app-deployment-pipeline.md](INVESTIGATE-enonic-app-deployment-pipeline.md) |
| **Content (data)** | XP internal repository | Data Toolbox export/import or `enonic dump`/`enonic load` | See [INVESTIGATE-enonic-content-deployment.md](INVESTIGATE-enonic-content-deployment.md) |

---

## Recommendation

**Option B (Plain Docker/StatefulSet)** — confirmed as the right approach because:
1. UIS runs on Rancher Desktop (k3s) on developer laptops — resource-constrained
2. Single-node is sufficient for local development
3. Follows the same Helm/Ansible patterns as all other UIS services (storage via PVCs, ingress via Traefik)
4. Avoids cluster-wide CRDs and operator overhead
5. Developer gets everything needed: Content Studio, admin console, APIs, hot deploy, CLI access

### Decisions Made

- **Deployment**: Option B — plain Docker/StatefulSet, no operator
- **Category**: INTEGRATION, manifest number **085**
- **Ingress**: `HostRegexp(`enonic\..+`)` — works across localhost, Tailscale, and Cloudflare domains like all other services
- **Storage**: Standard PVC via cluster storage class
- **Access**: `http://enonic.localhost` (port 8080) — Content Studio, admin console, headless APIs
- **App deployment**: Sidecar pull pipeline — see [INVESTIGATE-enonic-app-deployment-pipeline.md](INVESTIGATE-enonic-app-deployment-pipeline.md). Port 4848 not exposed.

### Proposed Files

| Piece | File |
|-------|------|
| Service definition | `provision-host/uis/services/integration/service-enonic.sh` (must include website metadata — `uis-docs.sh` generates JSON from these for the docs website) |
| Setup playbook | `ansible/playbooks/085-setup-enonic.yml` |
| Remove playbook | `ansible/playbooks/085-remove-enonic.yml` |
| Config / Helm values | `manifests/085-enonic-config.yaml` |
| StatefulSet (includes sidecar) | `manifests/085-enonic-statefulset.yaml` |
| IngressRoute | `manifests/085-enonic-ingressroute.yaml` |
| Documentation | `website/docs/packages/integration/enonic.md` |

App deployment CLI files are listed in [INVESTIGATE-enonic-app-deployment-pipeline.md](INVESTIGATE-enonic-app-deployment-pipeline.md).

---

## Next Steps

- [x] Decide on Option A vs Option B → **Option B (Plain Docker)**
- [x] Choose category and manifest number → **INTEGRATION, 085**
- [x] Determine ES conflict → **No conflict (embedded ES is internal to the Enonic pod)**
- [x] Confirm developer workflow works without operator → **Yes, all dev tools work**
- [x] Decide ingress routing → **`HostRegexp(`enonic\..+`)` — matches `enonic.localhost`, `enonic.urbalurba.no`, etc.**
- [x] Figure out content and app deployment workflow → **See "Content and App Deployment Workflow" section**
- [x] Understand CI/CD and management API security → **Port 4848 stays on private network, JWT auth, never exposed publicly**
- [x] Investigate CI/CD reachability problem → **Same issue for enterprise Azure and local UIS — pipeline can't reach port 4848 without self-hosted agent or alternative approach**
- [x] Design app deployment pipeline → **Moved to separate investigation: [INVESTIGATE-enonic-app-deployment-pipeline.md](INVESTIGATE-enonic-app-deployment-pipeline.md)**
- [ ] Create PLAN-enonic-xp-deployment.md with implementation phases (base platform only)

