# Adding a Service

This guide walks through the complete process of adding a new infrastructure service to UIS. By the end, your service will be deployable with `./uis deploy myservice`, removable with `./uis undeploy myservice`, and visible in the docs.

## Overview

A UIS service consists of these pieces:

| Piece | File | Purpose |
|-------|------|---------|
| Service definition | `provision-host/uis/services/<category>/service-<id>.sh` | Metadata — tells the CLI about the service |
| Setup playbook | `ansible/playbooks/NNN-setup-<id>.yml` | Deploys the service via Helm or kubectl |
| Remove playbook | `ansible/playbooks/NNN-remove-<id>.yml` | Removes the service cleanly |
| Config / Helm values | `manifests/NNN-<id>-config.yaml` | Helm values or ConfigMap |
| IngressRoute | `manifests/NNN-<id>-ingressroute.yaml` | Traefik routing (if web-accessible) |
| Secrets entries | Three template files in `provision-host/uis/templates/` | Credentials (if needed) |
| Documentation | `website/docs/packages/<category>/<id>.md` | Docs website page |

The numbered prefix (`NNN`) comes from the manifest numbering convention for your service's category.

## Prerequisites

Before starting, read these pages for context:

- **[Provisioning Rules](../rules/provisioning.md)** — Ansible playbook patterns and conventions
- **[Secrets Management Rules](../rules/secrets-management.md)** — How secrets flow through the platform
- **[Ingress and Traefik Rules](../rules/ingress-traefik.md)** — Routing and IngressRoute patterns
- **[Kubernetes Deployment Rules](../rules/kubernetes-deployment.md)** — Service metadata, deploy flow, and categories
- **[Manifests Architecture](../architecture/manifests.md)** — Manifest organization and numbering

## Step 1: Choose a category and manifest number

Services are organized into categories. Pick the one that fits:

| Category ID | Manifest Range | Examples |
|-------------|----------------|----------|
| `OBSERVABILITY` | 030-039, 230-239 | Prometheus, Grafana, Loki |
| `AI` | 200-229 | OpenWebUI, LiteLLM |
| `ANALYTICS` | 300-399 | Spark, JupyterHub |
| `IDENTITY` | 070-079 | Authentik |
| `DATABASES` | 040-099 | PostgreSQL, MongoDB, Redis |
| `MANAGEMENT` | 600-799 | pgAdmin, ArgoCD |
| `NETWORKING` | 800-820 | Tailscale, Cloudflare tunnels |
| `STORAGE` | 000-009 | Storage classes |
| `INTEGRATION` | 080-091 | RabbitMQ, Gravitee |

Pick an unused number within your category's range for the manifest prefix.

## Step 2: Create the service definition

Create `provision-host/uis/services/<category>/service-<id>.sh`:

```bash
#!/bin/bash
# service-myservice.sh - My Service metadata

# === Service Metadata (Required) ===
SCRIPT_ID="myservice"
SCRIPT_NAME="My Service"
SCRIPT_DESCRIPTION="Short description of what it does"
SCRIPT_CATEGORY="DATABASES"

# === Deployment (Required) ===
SCRIPT_PLAYBOOK="NNN-setup-myservice.yml"
SCRIPT_MANIFEST=""
SCRIPT_CHECK_COMMAND="kubectl get pods -n default -l app=myservice --no-headers 2>/dev/null | grep -q Running"
SCRIPT_REMOVE_PLAYBOOK="NNN-remove-myservice.yml"
SCRIPT_REQUIRES=""
SCRIPT_PRIORITY="50"

# === Deployment Details (Optional) ===
SCRIPT_HELM_CHART="repo/chart-name"
SCRIPT_NAMESPACE="default"

# === Website Metadata (Optional) ===
SCRIPT_ABSTRACT="Brief abstract for documentation"
SCRIPT_SUMMARY="Extended description for the documentation page"
SCRIPT_LOGO="myservice-logo.webp"
SCRIPT_WEBSITE="https://myservice.example.com"
SCRIPT_TAGS="tag1,tag2,tag3"
SCRIPT_DOCS="/docs/packages/category/myservice"
```

**Field reference:**

| Field | Required | Description |
|-------|----------|-------------|
| `SCRIPT_ID` | Yes | Unique identifier used in CLI commands |
| `SCRIPT_NAME` | Yes | Display name |
| `SCRIPT_DESCRIPTION` | Yes | One-line description |
| `SCRIPT_CATEGORY` | Yes | Must match a category ID from the table above |
| `SCRIPT_PLAYBOOK` | Yes | Ansible playbook filename (in `ansible/playbooks/`) |
| `SCRIPT_MANIFEST` | No | Kubernetes manifest (alternative to playbook — not currently used by any service) |
| `SCRIPT_CHECK_COMMAND` | No | Shell command that exits 0 if service is healthy |
| `SCRIPT_REMOVE_PLAYBOOK` | No | Playbook for removal |
| `SCRIPT_REQUIRES` | No | Space-separated service IDs this service depends on |
| `SCRIPT_PRIORITY` | No | Deploy order — lower numbers deploy first (default: 50) |
| `SCRIPT_HELM_CHART` | No | Helm chart reference |
| `SCRIPT_NAMESPACE` | No | Kubernetes namespace |

Website metadata fields (`SCRIPT_ABSTRACT`, `SCRIPT_TAGS`, etc.) are consumed by `uis-docs.sh` to generate JSON for the documentation website. Fill them in.

**Constraints:**
- `SCRIPT_PLAYBOOK` and `SCRIPT_MANIFEST` are mutually exclusive (playbook takes precedence)
- Each variable must be on its own line in `KEY="value"` format (the scanner parses line-by-line)
- Files starting with `_` are ignored by the scanner

## Step 3: Create the Helm values / config manifest

Create `manifests/NNN-myservice-config.yaml` with Helm values or a ConfigMap. This file is referenced by the setup playbook.

See **[Manifests Architecture](../architecture/manifests.md)** for organization patterns.

## Step 4: Create the IngressRoute manifest

If your service has a web UI, create `manifests/NNN-myservice-ingressroute.yaml`:

```yaml
apiVersion: traefik.io/v1alpha1
kind: IngressRoute
metadata:
  name: myservice
  namespace: myservice-namespace
spec:
  entryPoints:
    - web
  routes:
    - match: "HostRegexp(`myservice\\..+`)"
      kind: Rule
      services:
        - name: myservice-svc
          port: 8080
```

Use `HostRegexp` so the route works across localhost, Tailscale, and Cloudflare domains without changes. See **[Ingress and Traefik Rules](../rules/ingress-traefik.md)** for all routing patterns.

## Step 5: Create the setup playbook

Create `ansible/playbooks/NNN-setup-myservice.yml`:

```yaml
---
# NNN-setup-myservice.yml
# Deploy My Service to the Kubernetes cluster
#
# Usage:
#   ansible-playbook NNN-setup-myservice.yml -e "target_host=rancher-desktop"

- name: Deploy My Service
  hosts: localhost
  connection: local
  gather_facts: false

  vars:
    _target: "{{ target_host | default('rancher-desktop') }}"
    merged_kubeconf_file: "/mnt/urbalurbadisk/.uis.secrets/generated/kubeconfig/kubeconf-all"
    namespace: "myservice-namespace"
    component_name: "myservice"
    manifests_folder: "/mnt/urbalurbadisk/manifests"
    config_file: "{{ manifests_folder }}/NNN-myservice-config.yaml"
    ingressroute_file: "{{ manifests_folder }}/NNN-myservice-ingressroute.yaml"
    helm_release_name: "myservice"
    helm_chart: "repo/myservice"

  tasks:
    - name: "1. Create {{ namespace }} namespace"
      kubernetes.core.k8s:
        name: "{{ namespace }}"
        api_version: v1
        kind: Namespace
        state: present
        kubeconfig: "{{ merged_kubeconf_file }}"

    - name: "2. Install/upgrade via Helm"
      kubernetes.core.helm:
        name: "{{ helm_release_name }}"
        chart_ref: "{{ helm_chart }}"
        release_namespace: "{{ namespace }}"
        create_namespace: true
        state: present
        kubeconfig: "{{ merged_kubeconf_file }}"
        values_files:
          - "{{ config_file }}"

    - name: "3. Deploy IngressRoute"
      kubernetes.core.k8s:
        state: present
        src: "{{ ingressroute_file }}"
        kubeconfig: "{{ merged_kubeconf_file }}"

    - name: "4. Wait for {{ component_name }} to be ready"
      kubernetes.core.k8s_info:
        kind: Pod
        namespace: "{{ namespace }}"
        label_selectors:
          - "app.kubernetes.io/name={{ component_name }}"
        kubeconfig: "{{ merged_kubeconf_file }}"
      register: service_pods
      retries: 20
      delay: 15
      until: >
        service_pods.resources | length > 0 and
        service_pods.resources[0].status.phase == "Running"

    - name: "5. Deployment complete"
      ansible.builtin.debug:
        msg:
          - "{{ component_name }} deployed successfully"
          - "URL: http://{{ component_name }}.localhost"
```

**Key conventions:**
- `_target` uses underscore prefix (avoids Ansible recursive template issue)
- Always pass `kubeconfig: "{{ merged_kubeconf_file }}"` to k8s modules
- Number task names for readability
- Use `changed_when: false` on read-only shell commands
- Use `no_log: true` on any task handling secrets

See **[Provisioning Rules](../rules/provisioning.md)** for full playbook conventions.

## Step 6: Create the remove playbook

Create `ansible/playbooks/NNN-remove-myservice.yml`:

```yaml
---
# NNN-remove-myservice.yml
# Remove My Service from the Kubernetes cluster

- name: Remove My Service
  hosts: localhost
  connection: local
  gather_facts: false

  vars:
    _target: "{{ target_host | default('rancher-desktop') }}"
    _remove_pvc: "{{ remove_pvc | default(false) | bool }}"
    merged_kubeconf_file: "/mnt/urbalurbadisk/.uis.secrets/generated/kubeconfig/kubeconf-all"
    namespace: "myservice-namespace"
    helm_release_name: "myservice"

  tasks:
    - name: "1. Check for Helm release"
      ansible.builtin.shell: >
        helm status {{ helm_release_name }} -n {{ namespace }}
        --kubeconfig {{ merged_kubeconf_file }}
      register: helm_check
      failed_when: false
      changed_when: false

    - name: "2. Remove Helm release"
      kubernetes.core.helm:
        name: "{{ helm_release_name }}"
        release_namespace: "{{ namespace }}"
        state: absent
        kubeconfig: "{{ merged_kubeconf_file }}"
      when: helm_check.rc == 0

    - name: "3. Remove PVCs (optional)"
      ansible.builtin.shell: >
        kubectl delete pvc -l app.kubernetes.io/name={{ helm_release_name }}
        -n {{ namespace }} --kubeconfig {{ merged_kubeconf_file }}
      when: _remove_pvc
      failed_when: false

    - name: "4. Remove IngressRoute"
      kubernetes.core.k8s:
        state: absent
        kind: IngressRoute
        api_version: traefik.io/v1alpha1
        name: "{{ helm_release_name }}"
        namespace: "{{ namespace }}"
        kubeconfig: "{{ merged_kubeconf_file }}"
      failed_when: false

    - name: "5. Removal complete"
      ansible.builtin.debug:
        msg: "{{ helm_release_name }} removed from {{ namespace }}"
```

**Key conventions:**
- Use `failed_when: false` on most tasks (service may already be removed)
- PVC removal is opt-in via `remove_pvc` flag (preserves data by default)

## Step 7: Add secrets (if needed)

If your service requires credentials, edit three template files in `provision-host/uis/templates/`:

**1. Add variables** to `secrets-templates/00-common-values.env.template`:

```bash
# My Service
MYSERVICE_API_KEY=your-api-key-here
MYSERVICE_DB_PASSWORD=${DEFAULT_DATABASE_PASSWORD}
```

**2. Add a Secret block** to `secrets-templates/00-master-secrets.yml.template`:

```yaml
---
apiVersion: v1
kind: Secret
metadata:
  name: urbalurba-secrets
  namespace: myservice
type: Opaque
stringData:
  MYSERVICE_API_KEY: "${MYSERVICE_API_KEY}"
  MYSERVICE_DB_PASSWORD: "${MYSERVICE_DB_PASSWORD}"
```

Or add keys to an existing namespace's secret block if your service deploys into `default`, `ai`, etc.

**3. Add defaults** to `default-secrets.env`:

```bash
DEFAULT_MYSERVICE_API_KEY="LocalDevMyService123"
```

**4. Read the secret** in your setup playbook:

```yaml
- name: Get API key from secrets
  ansible.builtin.shell: >
    kubectl get secret urbalurba-secrets -n myservice
    -o jsonpath="{.data.MYSERVICE_API_KEY}"
    --kubeconfig {{ merged_kubeconf_file }} | base64 -d
  register: api_key
  changed_when: false
```

**Password restrictions:** Do not use `!`, `$`, `` ` ``, `\`, or `"` in passwords — Bitnami Helm charts pass passwords through bash, which breaks on these characters.

See **[Secrets Architecture](../architecture/secrets.md)** for the full secrets flow.

## Step 8: Add Helm repository (if needed)

If your service uses a Helm chart from a repository not already registered, add it to `ansible/playbooks/05-install-helm-repos.yml`. This playbook runs during cluster provisioning and ensures all Helm repos are available.

## Step 9: Add to enabled-services.conf

Add a commented-out entry to the default template at `provision-host/uis/templates/uis.extend/enabled-services.conf.default`. This lets users opt in by uncommenting the line.

Note: `./uis deploy myservice` automatically enables the service, so users don't need to manually edit this file. The default template just documents what's available.

## Step 10: Consider stack membership

If your service belongs to a logical group (e.g., a monitoring tool alongside Prometheus and Grafana), consider adding it to an existing stack or creating a new one in `provision-host/uis/lib/stacks.sh`.

See **[Kubernetes Deployment Rules](../rules/kubernetes-deployment.md)** for stack definitions.

## Step 11: Create documentation

1. Create `website/docs/packages/<category>/myservice.md`
2. Add the page to `website/sidebars.ts` under the appropriate category
3. Run `cd website && npm run build` to verify no broken links

See **[Documentation Standards](../rules/documentation.md)** for page conventions.

## Testing

Deploy, remove, and verify:

```bash
# Deploy the service (also auto-enables it)
./uis deploy myservice

# Check it's running
./uis status

# Test removal
./uis undeploy myservice

# Verify it appears correctly in the service list
./uis list

# Test just your service and its dependencies
./uis test-all --only myservice

# Build the docs site to check for broken links
cd website && npm run build
```

## Two deployment paths

UIS has two separate deployment concepts:

- **`./uis deploy`** — Deploys platform infrastructure services (databases, monitoring, auth, etc.). This is what this guide covers.
- **`./uis argocd register`** — Deploys user applications from external GitHub repos via ArgoCD. This is a completely different flow.

If you're packaging a platform service, follow this guide. If you're deploying a user-facing app from a GitHub repo, see the [ArgoCD pipeline docs](../../developing/argocd-pipeline.md).

## Reference services

Use these existing services as examples:

### Simple (manifest-only, no Helm): Whoami

```
provision-host/uis/services/management/service-whoami.sh
ansible/playbooks/025-setup-whoami-testpod.yml
manifests/070-whoami-service-and-deployment.yaml
manifests/025-whoami-ingressroute-*.yaml
```

### Medium (Helm-based database): PostgreSQL

```
provision-host/uis/services/databases/service-postgresql.sh
ansible/playbooks/040-database-postgresql.yml
ansible/playbooks/040-remove-database-postgresql.yml
manifests/042-database-postgresql-config.yaml
```

### Complex (Helm + secrets + auth): OpenWebUI

```
provision-host/uis/services/ai/service-openwebui.sh
ansible/playbooks/200-setup-open-webui.yml
ansible/playbooks/200-remove-open-webui.yml
manifests/200-ai-persistent-storage.yaml
manifests/208-openwebui-config.yaml
```
