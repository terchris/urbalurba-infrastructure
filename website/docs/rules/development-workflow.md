# Development Workflow Rules

**File**: `docs/rules-development-workflow.md`
**Purpose**: Define how to work with the urbalurba-infrastructure codebase, including file operations, command execution, and project standards
**Target Audience**: All contributors and AI assistants working with the repository
**Last Updated**: October 3, 2025

**⚠️ CRITICAL**: All paths in this document and throughout the project are **relative to the repository root** unless explicitly stated otherwise.

**Repository Root**: `/Users/terje.christensen/learn/redcross-public/urbalurba-infrastructure/`

---

## Rules

There are many rules to follow read docs/rules-readme.md for an overview. 
Or just all docs/rules-*.md 


---

## Path Convention

**When paths are referenced anywhere in this project:**

✅ **Correct:** `manifests/030-prometheus-config.yaml`
✅ **Correct:** `ansible/playbooks/030-setup-prometheus.yml`
✅ **Correct:** `docs/rules-development-workflow.md`

❌ **Wrong:** `/Users/terje.christensen/learn/redcross-public/urbalurba-infrastructure/manifests/030-prometheus-config.yaml`

**Exception:** Absolute paths are only used when referring to external locations or when explicitly needed for clarity.

---

## Two Development Workflows

Depending on who is working (AI assistant vs. human developer), there are different workflows:

---

### Workflow A: Claude Code (AI Assistant)

**Used when:** Claude Code AI assistant is performing tasks

**Characteristics:**
- Claude operates directly on the Mac host filesystem
- No manual file synchronization required
- Faster iteration and immediate feedback

**Operations:**

1. **File Operations** (Read/Write/Edit)
   ```
   Claude writes directly to:
   /Users/terje.christensen/learn/redcross-public/urbalurba-infrastructure/

   Examples:
   - Create: manifests/036-grafana-sovdev-verification.yaml
   - Edit: ansible/playbooks/030-setup-prometheus.yml
   - Read: docs/rules-development-workflow.md
   ```

2. **kubectl Commands** (Direct on Mac)
   ```bash
   kubectl get pods -n monitoring
   kubectl apply -f manifests/036-grafana-sovdev-verification.yaml
   kubectl logs -n monitoring -l app=grafana
   ```

3. **Ansible Playbooks** (Via provision-host container)
   ```bash
   docker exec provision-host bash -c "cd /mnt/urbalurbadisk/provision-host/kubernetes/11-monitoring/not-in-use && ./01-setup-prometheus.sh rancher-desktop"
   ```

4. **Verification** (Multiple methods)
   - kubectl on Mac
   - File reads on Mac
   - Container commands when needed
   - Direct curl/API calls from Mac

**Advantages:**
- ✅ No manual sync step
- ✅ Immediate feedback
- ✅ All changes in git repository
- ✅ Can iterate quickly

**Limitations:**
- Ansible playbooks must still run in provision-host container
- Some Ansible tasks require container context

---

### Workflow B: Manual (Human Developer)

**Used when:** Human developer is working directly with files and commands

**Characteristics:**
- Manual file synchronization required
- Work done both on Mac and in provision-host container
- More explicit control over each step

**Step-by-Step Process:**

**1. Edit Files on Mac**
```bash
# Work in repository root
cd /Users/terje.christensen/learn/redcross-public/urbalurba-infrastructure

# Edit files with your editor
vim manifests/030-prometheus-config.yaml
code ansible/playbooks/030-setup-prometheus.yml
```

**2. Execute Commands via UIS**
```bash
# Enter the provision host shell
./uis shell

# Or run commands directly
./uis deploy prometheus
./uis exec kubectl get pods -n monitoring
```

**4. Verify with kubectl (Mac or Container)**
```bash
# On Mac
kubectl get pods -n monitoring

# Or in container
kubectl get pods -n monitoring
```

**4. Update Documentation**
```bash
# On Mac
vim docs/rules-development-workflow.md
```

---

## Directory Structure

**Mac Host:**
```
/Users/terje.christensen/learn/redcross-public/urbalurba-infrastructure/
├── manifests/               # Kubernetes manifests (Helm values, ConfigMaps, IngressRoutes)
├── ansible/
│   └── playbooks/           # Ansible playbooks for automation
├── provision-host/
│   └── kubernetes/
│       └── 11-monitoring/   # Monitoring setup scripts
│           └── not-in-use/  # Testing area for new scripts
├── .uis.secrets/            # Secrets management (NOT in git)
│   ├── scripts/
│   │   └── create-kubernetes-secrets.sh
│   └── generated/kubernetes/
│       └── kubernetes-secrets.yml
├── docs/                     # Documentation and rules
└── terchris/                # Personal working area (experiments, backups)
```

**Provision-Host Container (after sync):**
```
/mnt/urbalurbadisk/
├── manifests/
├── ansible/playbooks/
├── provision-host/kubernetes/
├── .uis.secrets/
└── docs/
```

**Mirror Relationship:**
The provision-host container at `/mnt/urbalurbadisk/` mirrors the Mac repository at `/Users/terje.christensen/learn/redcross-public/urbalurba-infrastructure/`

---

## File Naming Conventions

**⚠️ See [doc/rules-naming-conventions.md](rules-naming-conventions.md) for complete details.**

**Quick Summary:**

**Manifests:** `NNN-component-type.yaml`
- 000-029: Core infrastructure
- 030-039: Monitoring (Prometheus, Grafana, Loki, Tempo, OTEL)
- 040-069: Databases
- 070-079: Authentication
- 200-229: AI services

**Ansible Playbooks:** `NNN-action-component.yml`
- Number matches manifest (030 playbook → 030 manifest)
- Actions: `setup-`, `remove-`, `update-`, `test-`

**Shell Scripts:** `NN-action-component.sh`
- Sequential numbering (01, 02, 03...)
- Wrappers around Ansible playbooks

**Example Flow:**
```
manifests/030-prometheus-config.yaml
    ↓ (used by)
ansible/playbooks/030-setup-prometheus.yml
    ↓ (called by)
provision-host/kubernetes/11-monitoring/not-in-use/01-setup-prometheus.sh
```

---

## Command Execution Rules

### kubectl Commands
**Location:** Can run on **Mac host OR provision-host container**

```bash
# Both work identically
kubectl get pods -n monitoring
kubectl apply -f manifests/030-prometheus-config.yaml
kubectl logs -n monitoring pod-name
```

### Ansible Playbooks
**Location:** Must run in **provision-host container**

```bash
# CORRECT: Via shell script wrapper
docker exec provision-host bash -c "cd /mnt/urbalurbadisk/provision-host/kubernetes/11-monitoring/not-in-use && ./01-setup-prometheus.sh rancher-desktop"

# ALSO CORRECT: Inside container
docker exec -it provision-host bash
cd /mnt/urbalurbadisk/provision-host/kubernetes/11-monitoring/not-in-use
./01-setup-prometheus.sh rancher-desktop

# WRONG: Calling playbook directly (skip script wrapper)
ansible-playbook ansible/playbooks/030-setup-prometheus.yml -e "target_host=rancher-desktop"
```

**Why scripts?** Shell scripts provide proper context, error handling, and wrapper logic around Ansible playbooks.

### File Operations
**Location:** **Mac host** (both workflows)

```bash
# Edit files on Mac
vim manifests/036-grafana-sovdev-verification.yaml

# Files in the image are pre-built; secrets are volume-mounted
```

---

## Project Rules and Standards

**⚠️ IMPORTANT:** This project has established rules that MUST be followed:

### Core Rules Documents

1. **[doc/rules-development-workflow.md](rules-development-workflow.md)** (this file)
   - Development workflows (Claude Code vs Manual)
   - File operations and command execution
   - Directory structure and naming conventions

2. **[doc/rules-readme.md](rules-readme.md)** *(to be created)*
   - Overview of all project rules
   - Quick reference for developers

3. **[doc/rules-automated-kubernetes-deployment.md](rules-automated-kubernetes-deployment.md)** *(to be created)*
   - Ansible playbook patterns
   - Helm chart deployment standards
   - External manifest file usage (not inline values)

4. **[doc/rules-ingress-traefik.md](rules-ingress-traefik.md)** *(to be created)*
   - IngressRoute patterns
   - HostRegexp for multi-domain support
   - Middleware configuration (auth, CSP headers)

5. **[doc/rules-secrets-management.md](rules-secrets-management.md)** *(to be created)*
   - .uis.secrets system usage
   - Never commit secrets to git
   - urbalurba-secrets ConfigMap pattern

6. **[doc/rules-provisioning.md](rules-provisioning.md)** *(to be created)*
   - Shell script organization
   - Naming conventions
   - Testing patterns

7. **[doc/rules-git-workflow.md](rules-git-workflow.md)** *(to be created)*
   - Commit message standards
   - Branch naming
   - PR requirements

8. **[doc/rules-howtodoc.md](rules-howtodoc.md)** *(to be created)*
   - Documentation structure
   - Markdown formatting
   - Usage instructions pattern

**Before making changes to the codebase, review relevant rules files to ensure compliance.**

---

## Quick Reference

### Common Tasks

**Create new manifest:**
```bash
# 1. Determine number range (030-039 for monitoring)
# 2. Create file with proper header
vim manifests/036-grafana-sovdev-verification.yaml
```

**Create new Ansible playbook:**
```bash
# 1. Match manifest number (036 → 036-setup-*.yml)
# 2. Reference external manifest with -f flag
vim ansible/playbooks/036-setup-grafana-sovdev.yml
```

**Deploy to cluster:**
```bash
# Deploy via UIS
./uis shell
cd /mnt/urbalurbadisk/provision-host/kubernetes/11-monitoring/not-in-use
./06-setup-grafana-sovdev.sh rancher-desktop
```

**Verify deployment:**
```bash
kubectl get pods -n monitoring
kubectl get configmap -n monitoring
kubectl logs -n monitoring -l app=grafana
```

---

## Troubleshooting

### Playbook fails with file not found
**Problem:** Ansible can't find manifest file
**Solution:** Check that file exists at correct path relative to repository root

### kubectl command fails
**Problem:** Cannot connect to cluster
**Solution:** Verify Rancher Desktop is running, check `kubectl config current-context`

### Script permission denied
**Problem:** Shell script not executable
**Solution:** `chmod +x provision-host/kubernetes/11-monitoring/not-in-use/XX-setup-component.sh`

---

## Summary

**Key Points:**
1. ✅ All paths are relative to repository root
2. ✅ Use `./uis` CLI for container management and service deployment
3. ✅ Ansible playbooks run in provision-host container
4. ✅ kubectl works on Mac or container
5. ✅ Follow numbering conventions (manifests, playbooks, scripts)
6. ✅ Always review relevant docs/rules-*.md files before changes

**When in doubt:**
- Check this document
- Review other docs/rules-*.md files
- Look at existing examples in the codebase
- Follow established patterns
