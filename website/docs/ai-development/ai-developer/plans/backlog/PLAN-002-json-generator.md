# Plan: Generate JSON Data from Script Metadata

> **IMPLEMENTATION RULES:** Before implementing this plan, read and follow:
> - [WORKFLOW.md](../../WORKFLOW.md) - The implementation process
> - [PLANS.md](../../PLANS.md) - Plan structure and best practices

## Status: Backlog

**Goal**: Create a Node.js script that generates `services.json` and optionally `stacks.json` by scanning metadata embedded in shell scripts.

**Last Updated**: 2026-01-19

**Priority**: Medium (enhances maintainability, not blocking)

**Depends On**: PLAN-001-branding-setup (JSON structure must be finalized first)

---

## Overview

Adopt the same self-documenting pattern used in DevContainer Toolbox (DCT). Each setup script in `provision-host/kubernetes/` will contain metadata fields that describe the service. A Node.js scanner will read these scripts and generate the JSON data files for the documentation website.

### Benefits

- **Single source of truth** - Metadata lives with the script
- **Self-documenting** - Each script describes itself
- **Easy to maintain** - Update script metadata, regenerate JSON
- **Consistent with DCT** - Same pattern across SovereignSky projects

---

## Phase 1: Define Script Metadata Format

### Metadata Fields

Each `setup-*.sh` script will include these fields:

```bash
#!/bin/bash
# file: provision-host/kubernetes/11-monitoring/01-setup-prometheus.sh
#
# Brief description of what this script installs.
#
#------------------------------------------------------------------------------
# METADATA - Used by JSON generator for documentation
#------------------------------------------------------------------------------

# --- Core Metadata ---
SCRIPT_ID="prometheus"
SCRIPT_NAME="Prometheus"
SCRIPT_DESCRIPTION="Time-series metrics collection and alerting"
SCRIPT_CATEGORY="MONITORING"

# --- Extended Metadata (for website documentation) ---
SCRIPT_TAGS="monitoring metrics alerting timeseries"
SCRIPT_ABSTRACT="Pull-based metrics collection with powerful query language."
SCRIPT_LOGO="prometheus-logo.svg"
SCRIPT_WEBSITE="https://prometheus.io"
SCRIPT_SUMMARY="Prometheus scrapes metrics from services and stores time-series data. Configured with service discovery and alerting rules for the stack."
SCRIPT_MANIFEST="031-prometheus.yaml"
SCRIPT_PLAYBOOK="030-setup-prometheus.yml"
SCRIPT_DOCS="/docs/packages/monitoring/prometheus"
SCRIPT_RELATED="grafana alertmanager"
SCRIPT_REQUIRES=""

# --- Stack Metadata (optional, for services that are part of a stack) ---
SCRIPT_STACK="observability"
SCRIPT_STACK_POSITION="1"
SCRIPT_STACK_NOTE="Metrics collection and storage"
SCRIPT_STACK_OPTIONAL="false"

#------------------------------------------------------------------------------
# SCRIPT LOGIC BELOW
#------------------------------------------------------------------------------
```

### Field Mapping to JSON-LD

| Script Field | JSON-LD Field | Notes |
|--------------|---------------|-------|
| SCRIPT_ID | identifier | Lowercase, hyphenated |
| SCRIPT_NAME | name | Display name |
| SCRIPT_DESCRIPTION | description | Brief (1-2 sentences) |
| SCRIPT_CATEGORY | applicationCategory | Must match categories.json |
| SCRIPT_TAGS | tags | Space-separated → array |
| SCRIPT_ABSTRACT | abstract | One-line summary |
| SCRIPT_LOGO | logo | Filename in services/ |
| SCRIPT_WEBSITE | url | Official project URL |
| SCRIPT_SUMMARY | summary | Detailed description |
| SCRIPT_MANIFEST | manifest | Kubernetes manifest file |
| SCRIPT_PLAYBOOK | playbook | Ansible playbook file |
| SCRIPT_DOCS | docs | Path within site |
| SCRIPT_RELATED | related | Space-separated → array |
| SCRIPT_REQUIRES | requires | Space-separated → array |

### Tasks

- [ ] 1.1 Document metadata format in a README
- [ ] 1.2 Create template script with all metadata fields
- [ ] 1.3 Validate field names match DCT pattern where applicable

---

## Phase 2: Create Node.js Scanner

### Location

```
website/scripts/
├── generate-services-json.js   # Main scanner script
├── lib/
│   └── parse-script-metadata.js
└── README.md
```

### Scanner Logic

```javascript
// Pseudocode for generate-services-json.js

1. Scan all folders in provision-host/kubernetes/
2. For each folder (e.g., 11-monitoring/):
   - Find all *.sh files (excluding not-in-use/)
   - Parse SCRIPT_* variables from each file
   - Validate required fields exist
3. Transform to JSON-LD format
4. Merge with any manual overrides (optional)
5. Write to website/src/data/services.json
6. Optionally generate stacks.json from SCRIPT_STACK_* fields
```

### Tasks

- [ ] 2.1 Create `website/scripts/` folder
- [ ] 2.2 Implement `parse-script-metadata.js` - extracts SCRIPT_* variables
- [ ] 2.3 Implement `generate-services-json.js` - main scanner
- [ ] 2.4 Add validation for required fields
- [ ] 2.5 Add JSON-LD wrapper (@context, @type)
- [ ] 2.6 Add npm script: `npm run generate:services`

---

## Phase 3: Add Metadata to Existing Scripts

### Scripts to Update

Scan `provision-host/kubernetes/*/` for all setup scripts:

| Folder | Scripts | Category |
|--------|---------|----------|
| 01-core | setup-nginx.sh | CORE |
| 11-monitoring | 01-setup-prometheus.sh, 02-setup-tempo.sh, etc. | MONITORING |
| 02-databases | (in not-in-use) | DATABASES |
| 07-ai | (in not-in-use) | AI |
| 12-auth | (in not-in-use) | AUTHENTICATION |

### Tasks

- [ ] 3.1 Add metadata to all active scripts in 11-monitoring/
- [ ] 3.2 Add metadata to scripts in not-in-use/ folders (for documentation)
- [ ] 3.3 Verify all SCRIPT_CATEGORY values match categories.json
- [ ] 3.4 Verify all SCRIPT_REQUIRES references are valid service IDs

---

## Phase 4: Stack Generation (Optional)

If scripts include SCRIPT_STACK_* fields, generate stacks.json automatically.

### Logic

```javascript
1. Group services by SCRIPT_STACK value
2. Sort by SCRIPT_STACK_POSITION
3. Generate stack object with components array
4. Stack name/description could come from a separate stacks-meta.json
   or from the first service in the stack
```

### Tasks

- [ ] 4.1 Decide: Auto-generate stacks.json or keep manual?
- [ ] 4.2 If auto: implement stack grouping logic
- [ ] 4.3 If manual: document how stacks.json relates to SCRIPT_STACK fields

---

## Phase 5: Integration

### npm Scripts

```json
{
  "scripts": {
    "generate:services": "node scripts/generate-services-json.js",
    "prebuild": "npm run generate:services"
  }
}
```

### CI/CD Integration

- Add generation step to GitHub Actions workflow
- Optionally: fail build if generated JSON differs from committed (ensures scripts are source of truth)

### Tasks

- [ ] 5.1 Add npm scripts to package.json
- [ ] 5.2 Update GitHub Actions workflow
- [ ] 5.3 Document workflow in website/README.md

---

## Validation

- [ ] Scanner runs without errors
- [ ] Generated services.json matches JSON-LD schema
- [ ] All services from scripts appear in generated JSON
- [ ] Website builds successfully with generated data
- [ ] Changes to script metadata reflect in generated JSON

---

## Reference

### DCT Pattern

DevContainer Toolbox uses similar metadata in `.devcontainer/additions/install-*.sh`:

```bash
SCRIPT_ID="dev-python"
SCRIPT_VER="0.0.1"
SCRIPT_NAME="Python Development Tools"
SCRIPT_DESCRIPTION="Adds ipython, pytest-cov, and VS Code extensions"
SCRIPT_CATEGORY="LANGUAGE_DEV"
SCRIPT_TAGS="python pip ipython pytest coverage"
SCRIPT_ABSTRACT="Python development environment..."
SCRIPT_LOGO="dev-python-logo.webp"
SCRIPT_WEBSITE="https://python.org"
SCRIPT_SUMMARY="Complete Python development setup..."
SCRIPT_RELATED="dev-typescript dev-golang dev-rust"
```

### Files to Create

- `website/scripts/generate-services-json.js`
- `website/scripts/lib/parse-script-metadata.js`
- `website/scripts/README.md`
- Template: `provision-host/kubernetes/setup-template.sh`

### Files to Modify

- All `provision-host/kubernetes/*/setup-*.sh` scripts (add metadata)
- `website/package.json` (add npm scripts)
- `.github/workflows/docs.yml` (add generation step)
