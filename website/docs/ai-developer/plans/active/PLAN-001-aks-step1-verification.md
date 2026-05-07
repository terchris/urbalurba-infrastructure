# Plan: AKS Step 1 — Verify minimal working cluster end-to-end

> **IMPLEMENTATION RULES:** Before implementing this plan, read and follow:
> - [WORKFLOW.md](../../WORKFLOW.md) - The implementation process
> - [PLANS.md](../../PLANS.md) - Plan structure and best practices

## Status: Active

**Goal**: Take the unverified `platforms/aks/` OpenTofu drafts (merged 2026-04-09 via PR #120) through their first real end-to-end run against an Azure subscription, fix any gaps that surface, and earn the right to call AKS Step 1 *actually* shipped — by deploying `./uis deploy nginx` against the resulting cluster and watching its built-in connectivity tests pass.

**Last Updated**: 2026-05-07

**Investigation**: [INVESTIGATE-platform-provisioning-layer.md](./INVESTIGATE-platform-provisioning-layer.md) — Step 1 scope, verification bar, and gap-analysis findings.

---

## Problem Summary

`platforms/aks/` contains four scripts (`00-bootstrap-state.sh`, `01-apply.sh`, `02-post-apply.sh`, `03-destroy.sh`) plus an OpenTofu module (`tofu/main.tf` etc.) that have never been run against a real Azure subscription. One known issue from the 2026-05-07 gap analysis must be fixed before the first run can succeed: the `uis-provision-host` container has no `tofu` binary. There's an installer for `azure-cli` at `provision-host/uis/tools/install-azure-cli.sh` but no equivalent for OpenTofu.

Beyond that, the dominant risk is *un-run risk*: bugs and small omissions only surface when scripts execute against real Azure resources for the first time. This plan reserves a phase for that iterative discovery.

The other 2026-05-07 gap (missing `kubernetes-secrets.yml` apply step in `02-post-apply.sh`) is split out into [PLAN-002-aks-secrets-apply-parity.md](./PLAN-002-aks-secrets-apply-parity.md). The verification bar here is `./uis deploy nginx`, and nginx doesn't need cluster secrets — so the secrets-parity gap doesn't block this PLAN. It just means the cluster after this PLAN ships is verified for nginx but won't yet be ready for secret-using UIS services like postgresql. PLAN-002 closes that.

---

## Phase 1: OpenTofu installer

Add `tofu` to the on-demand `./uis tools install` system, mirroring the existing `install-azure-cli.sh`.

### Tasks

- [ ] 1.1 Create `provision-host/uis/tools/install-opentofu.sh`. Match the shape of `install-azure-cli.sh`:
  - `TOOL_ID="opentofu"`
  - `TOOL_NAME="OpenTofu"`
  - `TOOL_DESCRIPTION="Open-source infrastructure-as-code tool (Terraform fork)"`
  - `TOOL_CATEGORY="CLOUD_TOOLS"`
  - `TOOL_CHECK_COMMAND="command -v tofu"`
  - `TOOL_SIZE="~30MB"`
  - `TOOL_WEBSITE="https://opentofu.org/"`
  - `do_install()` runs the official installer with the apt-method (creates apt repo + installs system-wide), so the install pattern matches azure-cli's `sudo bash` flow:
    ```bash
    curl --proto '=https' --tlsv1.2 -fsSL https://get.opentofu.org/install-opentofu.sh -o /tmp/install-opentofu.sh
    chmod +x /tmp/install-opentofu.sh
    sudo /tmp/install-opentofu.sh --install-method deb
    rm /tmp/install-opentofu.sh
    ```
  - `do_uninstall()` removes the apt package and the apt source list (parallel to azure-cli's uninstall).

- [ ] 1.2 Confirm `./uis tools list` discovers the new entry — the listing logic in `provision-host/uis/lib/tool-installation.sh:get_all_tool_ids` reads any `install-*.sh` script's `TOOL_ID=` line, so no registry edit is needed.

### Validation

Tester runs:
```
docker exec -it uis-provision-host bash -lc "./uis tools list"
```
…and sees `opentofu` listed with status `❌ Not installed`. Then:
```
./uis tools install opentofu
tofu --version
```
…installs cleanly and reports a version `>= 1.6.0` (the minimum the existing `tofu/main.tf` requires).

---

## Phase 2: First-run verification by tester (against real Azure)

The tester runs the full `platforms/aks/` flow against an Azure subscription and reports results. This is where un-run risk surfaces.

### Tasks

- [ ] 2.1 Install tooling: `./uis tools install azure-cli && ./uis tools install opentofu`. Verify `az --version` and `tofu --version` both work.

- [ ] 2.2 Create `platforms/aks/azure-aks-config.sh` from the template (`platforms/aks/azure-aks-config.sh-template`). Copy `TENANT_ID`, `SUBSCRIPTION_ID`, location, and tag values from the existing working `hosts/azure-aks/azure-aks-config.sh`. Pick a globally-unique state storage account name (suggested form: `sahelpersnouistfstate` or similar — must be lowercase, 3-24 chars, available in Azure). Confirm `azure-aks-config.sh` is git-ignored before saving.

- [ ] 2.3 Log into Azure: `az login --tenant "$TENANT_ID" --use-device-code` (or reuse an existing session). Confirm `az account show` reports the right subscription and Contributor role is active (PIM activation may be needed via the portal).

- [ ] 2.4 Run `platforms/aks/scripts/00-bootstrap-state.sh`. Expected: state resource group, storage account, blob container, and blob versioning all created. Failure mode to watch for: storage account name collision (someone else owns the global name).

- [ ] 2.5 Run `platforms/aks/scripts/01-apply.sh`. Expected: `tofu init` configures the remote backend, `tofu plan` shows resource group + Log Analytics workspace + AKS cluster being created, tester reviews and confirms apply, ~5-10 min later the cluster is up and `kubectl get nodes` (using `$KUBECONFIG_FILE`) shows healthy node(s). Failure modes to watch: subscription-quota errors mid-apply (`hosts/azure-aks/check-aks-quota.sh` is not ported — accept the loud failure and address only if it bites), provider-version drift, or kubeconfig output mismatch.

- [ ] 2.6 Run `platforms/aks/scripts/02-post-apply.sh`. Expected: kubeconfig merge into `kubeconf-all` succeeds, context switches to the AKS cluster, storage class aliases apply, Traefik installs via Helm, external IP eventually assigned. Note: this script does *not* apply `kubernetes-secrets.yml` — that gap is closed in PLAN-002. nginx (the verification target) doesn't need cluster secrets, so this is fine for Step 1's bar. Failure modes: ansible playbook missing/broken, Helm repo unreachable, Traefik external IP stuck pending.

- [ ] 2.7 Verify with `./uis deploy nginx`. Expected: pod scheduled, service reachable, IngressRoute applied, and the in-cluster curl tests in `ansible/playbooks/020-setup-nginx.yml` steps 13 + 15 both succeed (test file + index page fetched via cluster-internal DNS). This is the verification bar from the investigation.

- [ ] 2.8 Tear-down: run `platforms/aks/scripts/03-destroy.sh`. Expected: clean removal of cluster, RG, and managed resources. State storage account survives (per the bootstrap design — it's outside the cluster RG). Confirm by `az group list` afterward that the cluster RG is gone and the state RG is still present.

- [ ] 2.9 Capture every observation — what worked, what failed, what was confusing — in a tester report. The report becomes the input to Phase 3.

### Validation

`./uis deploy nginx` succeeds end-to-end and the 020-setup-nginx.yml connectivity tests print the expected response. Tester confirms cluster is destroyed afterward (cost gate).

---

## Phase 3: Address gaps surfaced in Phase 2

This phase is intentionally open-ended — until Phase 2 runs, the catalogue of bugs is unknown. Each gap surfaces as a small commit that re-enables a previously-failing Phase 2 task. Re-runs continue until Phase 2 passes cleanly.

### Tasks (placeholder — to be enumerated as gaps surface)

- [ ] 3.x (per gap) Make the smallest fix that closes the gap — code or config. Prefer fixing in `platforms/aks/` source rather than working around in the config. Update this plan with the gap + fix as a new task entry so the history is visible.

- [ ] 3.y (per gap) Re-run the affected Phase 2 step (and any downstream steps that depend on it) until the gap is closed.

### Validation

Phase 2 tasks all pass on a fresh clean run (i.e., starting from `00-bootstrap-state.sh`).

---

## Phase 4: Status sync

Once Phase 2 passes cleanly, mark Step 1 actually shipped.

### Tasks

- [ ] 4.1 Update `INVESTIGATE-platform-provisioning-layer.md` Step 1 heading: replace "drafts merged 2026-04-09, **not yet verified end-to-end**" with "✅ Shipped (verified end-to-end YYYY-MM-DD)". Remove the "not done until tester has run …" caveat. Move the gap-analysis findings list into a "Findings from first-run verification" subsection that names which gaps were addressed in Phase 3 and which were intentionally deferred (including the secrets-apply parity, which moves to PLAN-002).

- [ ] 4.2 Update `1PRIORITY.md` Tier 0 row for `platform-provisioning-layer`: replace "Step 1 *drafts* merged but never run end-to-end" with "Step 1 verified end-to-end YYYY-MM-DD; PLAN-002 (secrets parity) and Step 2 (operational tooling) are the next concrete work."

- [ ] 4.3 Move this PLAN file to `completed/` once everything above is done.

### Validation

User confirms Step 1 status accurately reflects the verified state.

---

## Acceptance Criteria

- [ ] `provision-host/uis/tools/install-opentofu.sh` exists and follows the shape of `install-azure-cli.sh`. `./uis tools install opentofu` installs cleanly and `tofu --version` reports `>= 1.6.0`.
- [ ] Tester has run `00 → 01 → 02 → ./uis deploy nginx → 03` end-to-end against a real Azure subscription, with the `020-setup-nginx.yml` connectivity tests succeeding.
- [ ] Cluster has been cleanly destroyed at the end of the verification run (cost gate).
- [ ] `INVESTIGATE-platform-provisioning-layer.md` and `1PRIORITY.md` reflect Step 1 as shipped (not "drafts merged").
- [ ] This plan is in `completed/`.

---

## Files to Modify

- `provision-host/uis/tools/install-opentofu.sh` (new)
- `platforms/aks/azure-aks-config.sh` (new, git-ignored, tester sets up in Phase 2.2)
- `website/docs/ai-developer/plans/backlog/INVESTIGATE-platform-provisioning-layer.md` (Phase 4)
- `website/docs/ai-developer/plans/backlog/1PRIORITY.md` (Phase 4)
- `website/docs/ai-developer/plans/active/PLAN-001-aks-step1-verification.md` → `completed/` (Phase 4)
- Additional `platforms/aks/` files only as Phase 3 gaps require.

---

## Implementation Notes

- **Cost gate.** AKS clusters bill while running. The Phase 2 verification is expected to be a same-session run-through ending in `03-destroy.sh`. If a run is interrupted, run `03-destroy.sh` before stepping away from the keyboard.
- **State backend persists across destroys.** `00-bootstrap-state.sh` creates a state RG / storage account that is *not* torn down by `03-destroy.sh`. That's by design (state survives cluster recreate cycles). It costs a few cents a month, not a real concern.
- **No Key Vault, no ACR.** Step 1 deliberately matches the Rancher Desktop secrets workflow (`kubernetes-secrets.yml`). Azure-specific add-ons are deferred to "Future hardening" in the investigation.
- **Secrets parity is split out.** PLAN-002 closes the `kubernetes-secrets.yml` apply gap on `02-post-apply.sh`. nginx doesn't need it; everything else does. Sequencing is loose — PLAN-002 can run before or after this plan ships, but the natural order is verify first (this plan), then extend (PLAN-002).
- **Tester reports against this plan.** Phase 2's tester report is the highest-signal artifact. Capture surprises in detail — they shape Phase 3 and inform PLAN-002 and Step 2's eventual PLAN.
