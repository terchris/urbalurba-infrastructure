# Plan: Move AKS config to `.uis.secrets/cloud-accounts/azure-default.env`

> **IMPLEMENTATION RULES:** Before implementing this plan, read and follow:
> - [WORKFLOW.md](../../WORKFLOW.md) - The implementation process
> - [PLANS.md](../../PLANS.md) - Plan structure and best practices

## Status: Active

**Goal**: Replace the bash-file-in-tree config (`platforms/aks/azure-aks-config.sh`) with the documented `.uis.secrets/cloud-accounts/azure-default.env` convention. Single user-edited file; defaults visible inline as commented overrides; scripts use `${VAR:-default}` shell fallback. Aligns AKS with the cluster-secret pattern that `secrets.md` already documents.

**Last Updated**: 2026-05-08

**Related**:
- [INVESTIGATE-platform-provisioning-layer.md](./INVESTIGATE-platform-provisioning-layer.md) — Step 1 scope.
- [PLAN-001-aks-step1-verification.md](../active/PLAN-001-aks-step1-verification.md) — currently in Phase 2 (manual run-through). This restructure ships before that Phase 2 finishes; the operator switches to the new file location mid-walkthrough.
- [PLAN-001b-aks-manual-setup.md](./PLAN-001b-aks-manual-setup.md) — Phase 4 references the bash file; this PLAN updates it.
- [Secrets architecture doc](../../../contributors/architecture/secrets.md) — names `cloud-accounts/azure-default.env` as the existing pattern.

**Sequence**: this PLAN is the *small* restructure that lands first. The follow-up wizard (`./uis target add aks`) is a separate larger PLAN that builds on top of the file structure this PLAN locks in.

---

## Problem Summary

`platforms/aks/azure-aks-config.sh` is a bash file the operator copies from `azure-aks-config.sh-template`, fills in, and saves in-tree (gitignored at the platform-aks level only). It mixes Azure-account identity (tenant/subscription IDs that should sit alongside cluster-secret overrides under `.uis.secrets/`) with cluster-shape defaults (node size, autoscaler bounds), and uses unprefixed variable names (`TENANT_ID`) that don't match the `AZURE_*` convention the existing `cloud-accounts/azure.env.template` already uses.

The secrets architecture doc (`website/docs/contributors/architecture/secrets.md`) documents `cloud-accounts/azure-default.env` as the canonical home for Azure cloud-account values, complete with a path helper (`get_cloud_credentials_path "azure"`). AKS is the first concrete consumer of that pattern; this PLAN slots it in.

No split: a single user-edited file (`.uis.secrets/cloud-accounts/azure-default.env`) holds everything from required identity values down to optional cluster-shape overrides, with defaults commented inline so the operator sees them at the point of editing. Scripts source the file then use `${VAR:-default}` to fall back when the operator leaves something out.

---

## Phase 1: Extend `azure.env.template` with AKS-specific additions

The existing template at `provision-host/uis/templates/uis.secrets/cloud-accounts/azure.env.template` only carries `AZURE_TENANT_ID` + `AZURE_SUBSCRIPTION_ID` (plus a commented service-principal block we don't use yet). Extend it.

### Tasks

- [ ] 1.1 Edit `provision-host/uis/templates/uis.secrets/cloud-accounts/azure.env.template`. Keep the existing two required vars and the service-principal commented block. Add the following sections, each clearly grouped:

  ```bash
  # === REQUIRED — fill these in =====================================
  AZURE_TENANT_ID=""
  AZURE_SUBSCRIPTION_ID=""

  # Globally-unique state storage account name (3-24 lowercase chars).
  # Verify availability with: az storage account check-name --name <candidate>
  AZURE_STATE_STORAGE_ACCOUNT=""

  # === OPTIONAL — Azure tags for cost tracking ======================
  # Defaults to your sign-in email if left empty.
  # AZURE_TAG_BUSINESS_OWNER=""
  # AZURE_TAG_IT_OWNER=""
  # AZURE_TAG_COST_CENTER="helpers-no"

  # === OPTIONAL — AKS cluster-shape overrides =======================
  # Uncomment to override the defaults shown alongside.
  # AZURE_AKS_LOCATION="westeurope"
  # AZURE_AKS_RESOURCE_GROUP="rg-urbalurba-aks-weu"
  # AZURE_AKS_CLUSTER_NAME="azure-aks"
  # AZURE_AKS_NODE_SIZE="Standard_B2ms"
  # AZURE_AKS_NODE_COUNT=1
  # AZURE_AKS_MIN_COUNT=1
  # AZURE_AKS_MAX_COUNT=3
  # AZURE_AKS_OS_DISK_SIZE=30

  # === OPTIONAL — OpenTofu state backend layout =====================
  # AZURE_AKS_STATE_RESOURCE_GROUP="rg-urbalurba-tfstate"
  # AZURE_AKS_STATE_CONTAINER="tfstate"
  # AZURE_AKS_STATE_KEY="aks/terraform.tfstate"
  ```

- [ ] 1.2 Update the file's leading comment to reflect: copy to `.uis.secrets/cloud-accounts/azure-default.env`, edit, save. Mention that the AKS sections only matter if the user is provisioning AKS — Azure CLI itself only needs the tenant/subscription pair.

### Validation

Static check: `bash -n provision-host/uis/templates/uis.secrets/cloud-accounts/azure.env.template` parses clean. Visual review: every AKS variable from the current `platforms/aks/azure-aks-config.sh-template` has a counterpart with `AZURE_AKS_` prefix (or `AZURE_` for genuinely account-scoped ones).

---

## Phase 2: Update `platforms/aks/scripts/*.sh` to source from `cloud-accounts/`

All four scripts currently source `$SCRIPT_DIR/../azure-aks-config.sh`. Replace with the path-helper-resolved location plus inline defaults.

### Tasks

- [ ] 2.1 In each of `00-bootstrap-state.sh`, `01-apply.sh`, `02-post-apply.sh`, `03-destroy.sh`, replace the existing config-source block with:

  ```bash
  # Source the cloud-accounts helper for the path resolver
  source "/mnt/urbalurbadisk/provision-host/uis/lib/paths.sh"

  CONFIG_FILE="$(get_cloud_credentials_path azure)"

  if [[ ! -f "$CONFIG_FILE" ]]; then
      print_error "Azure cloud-account config not found: $CONFIG_FILE"
      echo "Copy the template first:"
      echo "  cp provision-host/uis/templates/uis.secrets/cloud-accounts/azure.env.template $CONFIG_FILE"
      echo "  # then fill in AZURE_TENANT_ID, AZURE_SUBSCRIPTION_ID, AZURE_STATE_STORAGE_ACCOUNT"
      exit 1
  fi

  source "$CONFIG_FILE"

  # Validate required values are set
  : "${AZURE_TENANT_ID:?Required in $CONFIG_FILE}"
  : "${AZURE_SUBSCRIPTION_ID:?Required in $CONFIG_FILE}"
  : "${AZURE_STATE_STORAGE_ACCOUNT:?Required in $CONFIG_FILE}"

  # Apply inline defaults for optional cluster-shape values
  AZURE_AKS_LOCATION="${AZURE_AKS_LOCATION:-westeurope}"
  AZURE_AKS_RESOURCE_GROUP="${AZURE_AKS_RESOURCE_GROUP:-rg-urbalurba-aks-weu}"
  AZURE_AKS_CLUSTER_NAME="${AZURE_AKS_CLUSTER_NAME:-azure-aks}"
  AZURE_AKS_NODE_SIZE="${AZURE_AKS_NODE_SIZE:-Standard_B2ms}"
  AZURE_AKS_NODE_COUNT="${AZURE_AKS_NODE_COUNT:-1}"
  AZURE_AKS_MIN_COUNT="${AZURE_AKS_MIN_COUNT:-1}"
  AZURE_AKS_MAX_COUNT="${AZURE_AKS_MAX_COUNT:-3}"
  AZURE_AKS_OS_DISK_SIZE="${AZURE_AKS_OS_DISK_SIZE:-30}"

  AZURE_AKS_STATE_RESOURCE_GROUP="${AZURE_AKS_STATE_RESOURCE_GROUP:-rg-urbalurba-tfstate}"
  AZURE_AKS_STATE_CONTAINER="${AZURE_AKS_STATE_CONTAINER:-tfstate}"
  AZURE_AKS_STATE_KEY="${AZURE_AKS_STATE_KEY:-aks/terraform.tfstate}"

  # Tags default to the signed-in user's email if not overridden
  if [[ -z "${AZURE_TAG_BUSINESS_OWNER:-}" ]] || [[ -z "${AZURE_TAG_IT_OWNER:-}" ]]; then
      _SIGNED_IN_EMAIL=$(az ad signed-in-user show --query userPrincipalName -o tsv 2>/dev/null || echo "")
      AZURE_TAG_BUSINESS_OWNER="${AZURE_TAG_BUSINESS_OWNER:-${_SIGNED_IN_EMAIL}}"
      AZURE_TAG_IT_OWNER="${AZURE_TAG_IT_OWNER:-${_SIGNED_IN_EMAIL}}"
  fi
  AZURE_TAG_COST_CENTER="${AZURE_TAG_COST_CENTER:-helpers-no}"

  # Derived (do not change)
  KUBECONFIG_FILE="/mnt/urbalurbadisk/kubeconfig/${AZURE_AKS_CLUSTER_NAME}-kubeconf"
  ```

- [ ] 2.2 Search-and-replace the rest of each script: every reference to the old unprefixed variables (`$TENANT_ID`, `$SUBSCRIPTION_ID`, `$RESOURCE_GROUP`, `$CLUSTER_NAME`, `$LOCATION`, `$NODE_COUNT`, `$NODE_SIZE`, `$MIN_COUNT`, `$MAX_COUNT`, `$OS_DISK_SIZE`, `$STATE_*`, `$TAG_*`) becomes the prefixed equivalent (`$AZURE_TENANT_ID`, `$AZURE_AKS_RESOURCE_GROUP`, etc.).

### Validation

`shellcheck platforms/aks/scripts/*.sh` parses clean. `grep -nE "\\\$(TENANT_ID|SUBSCRIPTION_ID|CLUSTER_NAME|RESOURCE_GROUP|NODE_SIZE|MIN_COUNT|MAX_COUNT|OS_DISK_SIZE|STATE_(RESOURCE_GROUP|STORAGE_ACCOUNT|CONTAINER|KEY)|TAG_)" platforms/aks/scripts/` returns no hits — every var is now `AZURE_*`-prefixed.

---

## Phase 3: Bash → tofu variable translation at the apply boundary

`tofu/main.tf` and `tofu/variables.tf` keep their existing unprefixed names (`tenant_id`, `subscription_id`, `node_count`, `cluster_name`, etc.) per Q-P — no tofu rename. The translation happens in `01-apply.sh` when generating `tofu/terraform.tfvars`.

### Tasks

- [ ] 3.1 In `01-apply.sh`, update the `cat > "$TFVARS_FILE" <<EOF` block so each tfvars line maps from the prefixed bash var to the unprefixed tofu var:

  ```bash
  cat > "$TFVARS_FILE" <<EOF
  # Auto-generated by 01-apply.sh from .uis.secrets/cloud-accounts/azure-default.env — do not edit manually
  tenant_id       = "$AZURE_TENANT_ID"
  subscription_id = "$AZURE_SUBSCRIPTION_ID"

  resource_group  = "$AZURE_AKS_RESOURCE_GROUP"
  cluster_name    = "$AZURE_AKS_CLUSTER_NAME"
  location        = "$AZURE_AKS_LOCATION"

  node_count      = $AZURE_AKS_NODE_COUNT
  node_size       = "$AZURE_AKS_NODE_SIZE"
  min_count       = $AZURE_AKS_MIN_COUNT
  max_count       = $AZURE_AKS_MAX_COUNT
  os_disk_size_gb = $AZURE_AKS_OS_DISK_SIZE

  tag_cost_center    = "$AZURE_TAG_COST_CENTER"
  tag_project        = "urbalurba-infrastructure"
  tag_environment    = "Sandbox"
  tag_business_owner = "$AZURE_TAG_BUSINESS_OWNER"
  tag_it_owner       = "$AZURE_TAG_IT_OWNER"
  EOF
  ```

  `tag_project` and `tag_environment` are baked into the script — they're code-level defaults, not user-overrideable for now. If a contributor later wants to override them, expand the override surface then.

- [ ] 3.2 Update `01-apply.sh`'s `tofu init` backend-config args and `ARM_ACCESS_KEY` fetch to use the prefixed bash var names:

  ```bash
  export ARM_ACCESS_KEY=$(az storage account keys list \
      --resource-group "$AZURE_AKS_STATE_RESOURCE_GROUP" \
      --account-name "$AZURE_STATE_STORAGE_ACCOUNT" \
      --query "[0].value" -o tsv)

  tofu init \
      -backend-config="resource_group_name=$AZURE_AKS_STATE_RESOURCE_GROUP" \
      -backend-config="storage_account_name=$AZURE_STATE_STORAGE_ACCOUNT" \
      -backend-config="container_name=$AZURE_AKS_STATE_CONTAINER" \
      -backend-config="key=$AZURE_AKS_STATE_KEY" \
      -reconfigure
  ```

### Validation

`shellcheck platforms/aks/scripts/01-apply.sh` parses clean. The generated `tofu/terraform.tfvars` (after a dry run sourcing a sample config) has unprefixed keys, matching `tofu/variables.tf`.

---

## Phase 4: Delete the obsolete `azure-aks-config.sh-template`

Once Phases 1–3 ship, `platforms/aks/azure-aks-config.sh-template` is unused. Delete it so contributors don't accidentally edit the wrong file.

### Tasks

- [ ] 4.1 `git rm platforms/aks/azure-aks-config.sh-template`.

- [ ] 4.2 Update `platforms/aks/README.md` (if it references the old template) to point at `.uis.secrets/cloud-accounts/azure-default.env` and the new template under `provision-host/uis/templates/uis.secrets/cloud-accounts/azure.env.template`.

- [ ] 4.3 Search-and-replace any other in-tree references: `grep -rn "azure-aks-config\.sh" --include="*.sh" --include="*.md"` — every hit becomes a reference to either the new template path or the new user-file path.

### Validation

`grep -rn "azure-aks-config.sh" .` returns no hits anywhere outside this PLAN's history. The old template file is gone.

---

## Phase 5: Update PLAN-001b Phase 4 + variable-mapping table

PLAN-001b's Phase 4 ("Configuration") still describes the old `platforms/aks/azure-aks-config.sh` flow. Update it to reflect the new file location and prefixed variable names. The variable-mapping table in Phase 3 (where each Phase 3 step's output maps to a Phase 4 variable) also needs the `AZURE_*` rename.

### Tasks

- [ ] 5.1 In `PLAN-001b-aks-manual-setup.md` Phase 4, replace the `cp ... azure-aks-config.sh` instruction with `cp provision-host/uis/templates/uis.secrets/cloud-accounts/azure.env.template .uis.secrets/cloud-accounts/azure-default.env` and the corresponding edit-and-source flow. Update the example values block to use `AZURE_*` prefixed names.

- [ ] 5.2 In Phase 3's "What you should now have written down" table, rename the variable column entries (`TENANT_ID` → `AZURE_TENANT_ID`, `SUBSCRIPTION_ID` → `AZURE_SUBSCRIPTION_ID`, `LOCATION` → `AZURE_AKS_LOCATION`, `NODE_SIZE` → `AZURE_AKS_NODE_SIZE`, `STATE_STORAGE_ACCOUNT` → `AZURE_STATE_STORAGE_ACCOUNT`, `TAG_*` → `AZURE_TAG_*`).

- [ ] 5.3 In Phase 4's git-ignore check, replace `git check-ignore -v platforms/aks/azure-aks-config.sh` with `git check-ignore -v .uis.secrets/cloud-accounts/azure-default.env` (which is gitignored as part of the whole `.uis.secrets/` tree).

### Validation

`grep -nE "azure-aks-config\.sh|TENANT_ID(?!_)" website/docs/ai-developer/plans/backlog/PLAN-001b-aks-manual-setup.md` (or equivalent inspection) shows zero hits — every mention is the new path/name.

---

## Phase 6: Verification — folds into PLAN-001 Phase 2

The user is currently mid-PLAN-001 Phase 2 (manual run-through). Once Phases 1–5 of this PLAN ship, they continue PLAN-001 Phase 2 from the updated PLAN-001b — copy the new template, fill in the new variable names, run the (updated) scripts.

### Tasks

- [ ] 6.1 Tester runs PLAN-001 Phase 2.2 onward with the updated PLAN-001b — verify each step works against the new file location and variable names. Any failure becomes a Phase 3 gap in PLAN-001 (not in this PLAN).

### Validation

PLAN-001 Phase 2.7 (`./uis deploy nginx`) still passes against an AKS cluster provisioned via the new file structure. No regression vs the old structure (which was never run end-to-end anyway).

---

## Acceptance Criteria

- [ ] `provision-host/uis/templates/uis.secrets/cloud-accounts/azure.env.template` extended with the AKS-specific sections.
- [ ] All four `platforms/aks/scripts/*.sh` source `$(get_cloud_credentials_path azure)` and use `${VAR:-default}` for optional values.
- [ ] `tofu/terraform.tfvars` generation maps prefixed bash → unprefixed tofu names; `tofu/variables.tf` and `tofu/main.tf` unchanged.
- [ ] `platforms/aks/azure-aks-config.sh-template` is deleted; no in-tree references remain.
- [ ] `PLAN-001b-aks-manual-setup.md` Phase 3 + Phase 4 reflect the new location and variable names.
- [ ] Tester can complete PLAN-001 Phase 2 (the AKS run-through) end-to-end against the new structure.
- [ ] This plan is in `completed/`.

---

## Files to Modify

- `provision-host/uis/templates/uis.secrets/cloud-accounts/azure.env.template` (extend)
- `platforms/aks/scripts/00-bootstrap-state.sh`
- `platforms/aks/scripts/01-apply.sh`
- `platforms/aks/scripts/02-post-apply.sh`
- `platforms/aks/scripts/03-destroy.sh`
- `platforms/aks/azure-aks-config.sh-template` (delete)
- `platforms/aks/README.md` (if it cites the old template)
- `website/docs/ai-developer/plans/backlog/PLAN-001b-aks-manual-setup.md`
- `website/docs/ai-developer/plans/active/PLAN-aks-config-cloud-accounts.md` → `completed/` (Phase 6)

---

## Implementation Notes

- **Why no `platforms/aks/defaults.env`.** Per the discussion that produced this PLAN: a separate "platform defaults" file added a layer without a load-bearing reason. Defaults live commented-inline in the template (so the operator sees them at the point of editing) and as `${VAR:-default}` in the scripts (so they apply when the operator leaves things out). One file for the operator to read, one place per script for the fallback.
- **Why `AZURE_AKS_*` prefix on AKS-specific values.** The single-file-per-provider model means future Azure-but-not-AKS work (e.g. Azure Container Apps if anyone needs them) would also live in `azure-default.env`. Distinct prefixes keep the namespaces clean. Account-level values (tenant/subscription/state-SA-name/tags) keep the shorter `AZURE_*` prefix since they're shared across any Azure work.
- **Why no tofu rename.** `tofu/variables.tf` is internal to the OpenTofu module; it has its own namespace. The bash-to-tofu translation already happens via `terraform.tfvars` generation; renaming inside tofu would be churn without payoff.
- **Why `KUBECONFIG_FILE` derives from `$AZURE_AKS_CLUSTER_NAME`.** Old template hard-coded `azure-aks-kubeconf`. New form accommodates a contributor running multiple clusters with different `AZURE_AKS_CLUSTER_NAME` values without overwriting kubeconfigs. Path stays under `/mnt/urbalurbadisk/kubeconfig/` (unchanged) — moving to `.uis.secrets/generated/kubeconfig/` is a separate concern tied to the kubeconfig-merge work flagged in `secrets.md`.
- **Sequencing risk.** This PLAN ships *during* PLAN-001 Phase 2. The user is mid-runbook; after this lands, they redo the Phase 4 step (config setup) once with the new file location. The scripts and tofu provider versions don't change, so the actual AKS provisioning behaviour is identical — only the configuration entry-point changes.
