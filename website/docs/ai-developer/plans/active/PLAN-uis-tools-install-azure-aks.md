# Plan: Add `./uis tools install azure-aks` meta-tool

> **IMPLEMENTATION RULES:** Before implementing this plan, read and follow:
> - [WORKFLOW.md](../../WORKFLOW.md) - The implementation process
> - [PLANS.md](../../PLANS.md) - Plan structure and best practices

## Status: Active

**Goal**: Add a single `./uis tools install azure-aks` command that installs both AKS dependencies (`azure-cli` and `opentofu`) in one shot. Replaces today's two-command pattern (`./uis tools install azure-cli` + `./uis tools install opentofu` + *know* both are needed). This is **PLAN #1 of 4** spawned by [INVESTIGATE-aks-novice-onboarding.md](../backlog/INVESTIGATE-aks-novice-onboarding.md); it's the smallest and unblocks the rest.

**Last Updated**: 2026-05-10

**Source**: [INVESTIGATE-aks-novice-onboarding.md](../backlog/INVESTIGATE-aks-novice-onboarding.md), all 15 design questions decided 2026-05-10. Q2 specifically: meta-tools are regular `install-*.sh` scripts that delegate inside `do_install`; no new "meta-tool" concept in the wrapper.

---

## Problem Summary

A novice onboarding to AKS today has to know — and run — two separate `./uis tools install` commands before they can do anything useful:

```bash
./uis tools install azure-cli   # for `az`
./uis tools install opentofu    # for `tofu`
```

Nothing tells them both are required until `01-apply.sh` fails with a missing-binary error two minutes into provisioning. The investigation settled this by adding a meta-installer that bundles the two:

```bash
./uis tools install azure-aks   # for everything AKS needs
```

The meta-installer is a regular `install-*.sh` script that delegates inside its `do_install`. The wrapper at `provision-host/uis/lib/tool-installation.sh:184` (`install_tool`) handles idempotency via `TOOL_CHECK_COMMAND` and prints status — it doesn't care that `do_install` is "really" a delegator. Same lister, same install path, same uninstall path. One extra file. Zero changes to existing scripts.

---

## Out of Scope

- **Adding `kubelogin` to the bundle.** Today's `platforms/aks/tofu/main.tf` uses local-account auth (no AAD-integrated RBAC), so `kubelogin` is not invoked. Adding it would be needed only if we later switch to AAD-integrated AKS; that's a separate architectural decision (see "Out of Scope" in the parent investigation).
- **Generalizing meta-tools as a first-class concept** in `tool-installation.sh` (categories, dependency graphs, etc.). Per Q2, we deliberately stay with the regular-script-that-delegates pattern.
- **Adding `TOOL_CATEGORY=META` grouping to `./uis tools list`'s output rendering**. The metadata is set on the new script so a future polish PR can group; the rendering itself stays flat for this PR.
- **Refactoring `tool-installation.sh`**. The recursive `install_tool` call from inside a meta-tool's `do_install` works today (the subshell at line 213-221 inherits parent functions). No wrapper changes needed.
- **`./uis platform init/up/down azure-aks` wrappers.** Those are PLANs #2/3/4. This PLAN only adds the dependency installer.

---

## Phase 1: Add the meta-installer script

Add a single file at `provision-host/uis/tools/install-azure-aks.sh`. Follows the contract pattern established in PR #152 (tool-installer error-handling).

### Tasks

- [x] 1.1 Create `provision-host/uis/tools/install-azure-aks.sh`:

  ```bash
  #!/bin/bash
  # install-azure-aks.sh - AKS dependencies meta-installer

  # === Tool Metadata ===
  TOOL_ID="azure-aks"
  TOOL_NAME="Azure AKS dependencies"
  TOOL_DESCRIPTION="Bundle: azure-cli + opentofu (everything ./uis platform <verb> azure-aks needs)"
  TOOL_CATEGORY="META"
  TOOL_CHECK_COMMAND="command -v az >/dev/null && command -v tofu >/dev/null"
  TOOL_SIZE="~667MB (637 + 30)"
  TOOL_WEBSITE="https://learn.microsoft.com/azure/aks/"

  # Contract:
  #   - do_install MUST exit non-zero on any failure (set -euo pipefail).
  #   - Idempotency is enforced by the wrapper (tool-installation.sh:194) via
  #     TOOL_CHECK_COMMAND — do not add an "already installed" guard here.
  #   - This is a meta-installer: do_install delegates to install_tool for each
  #     component. Component idempotency is handled inside install_tool, so re-runs
  #     skip already-installed components automatically.

  do_install() {
      set -euo pipefail
      echo "Installing Azure AKS dependencies (azure-cli + opentofu)..."
      install_tool azure-cli
      install_tool opentofu
  }

  do_uninstall() {
      set -euo pipefail
      echo "azure-aks is a bundle. To uninstall its components, run:"
      echo "  ./uis tools uninstall azure-cli"
      echo "  ./uis tools uninstall opentofu"
      echo "(left as separate commands so you don't accidentally remove a component"
      echo " you still want for other purposes.)"
  }
  ```

  Notes on shape:
  - Sequential `install_tool` statements (not `&&`-chained) so `set -e` aborts on the first failure (per Q3). `&&`-chains suppress `set -e` aborts.
  - `TOOL_CHECK_COMMAND` is a compound (`command -v az >/dev/null && command -v tofu >/dev/null`). The wrapper's `eval` evaluates it; both must succeed for the meta-tool to count as installed.
  - `do_uninstall` is informational only (per Q2). Print the two component-uninstall commands; don't tear down sub-tools that the user might want for other reasons.

### Validation (Phase 1)

- [x] 1.2 `bash -n provision-host/uis/tools/install-azure-aks.sh` parses cleanly.
- [ ] 1.3 `./uis tools list` shows `azure-aks` as a row alongside `azure-cli`, `aws-cli`, `gcp-cli`, `opentofu`. The listed name is "Azure AKS dependencies", description starts with "Bundle:". **(deferred to tester — UIS contributor does not run containers)**
- [ ] 1.4 On a fresh container with neither `az` nor `tofu` installed: `./uis tools list` shows `azure-aks` as `❌ Not installed`. **(deferred to tester)**

---

## Phase 2: Verify in a clean container (tester round)

End-to-end verification on a container where neither component is pre-installed. Establishes that cold install, warm re-run, partial-state re-run, and post-install state inspection all behave correctly.

### Tasks

- [ ] 2.1 Cold install on a clean container:

  ```bash
  docker exec uis-provision-host bash -lc '
    ./uis tools install azure-aks
  '
  ```

  Expected: streamed output from azure-cli's installer (apt-get update, key install, az install) followed by opentofu's installer (curl + bash + apt install), ending with "✓ Azure AKS dependencies installed successfully" or similar; exit 0; takes a few minutes; `command -v az && command -v tofu` both resolve afterward.

- [ ] 2.2 Warm re-run (idempotent):

  ```bash
  docker exec uis-provision-host bash -lc '
    time ./uis tools install azure-aks
  '
  ```

  Expected: wrapper's `is_tool_installed` short-circuit fires at the top because `TOOL_CHECK_COMMAND` already succeeds. Logs "azure-aks is already installed" and exits 0 in &lt;1 second.

- [ ] 2.3 Partial-state re-run: simulate "azure-cli installed but opentofu not" (e.g. via `apt-get remove tofu`) then re-run:

  ```bash
  docker exec uis-provision-host bash -lc '
    sudo apt-get remove -y tofu
    command -v az && ! command -v tofu && echo "partial state confirmed"
    ./uis tools install azure-aks
    command -v az && command -v tofu && echo "both restored"
  '
  ```

  Expected: `TOOL_CHECK_COMMAND` returns false (since `command -v tofu` fails); wrapper proceeds to `do_install`; `install_tool azure-cli` is a no-op (already installed); `install_tool opentofu` does the install; both binaries present afterward.

- [ ] 2.4 List inspection (final state):

  ```bash
  docker exec uis-provision-host bash -lc '
    ./uis tools list | grep -E "azure-aks|azure-cli|opentofu"
  '
  ```

  Expected: all three rows show `✅ Installed`.

- [ ] 2.5 Forced-failure demo (optional but valuable for the PR description): temporarily break `install-opentofu.sh`'s URL, run `./uis tools install azure-aks` on a clean container, verify the meta-installer exits non-zero with a clear error after azure-cli succeeds (per Q3: stop, no rollback, log clearly which step failed).

### Validation (Phase 2)

Tester round closes when 2.1–2.4 all pass. The forced-failure (2.5) is a "nice-to-have" demonstration that the failure mode works as designed.

---

## Phase 3: Update the tools reference docs

Small doc touch-up so the new meta-tool is discoverable.

### Tasks

- [x] 3.1 Add `azure-aks` to `website/docs/reference/tools.md`'s installable-tools section. Source the description, size, and install command verbatim from the new script's metadata (mirror the existing entries for `azure-cli` / `opentofu`).

- [x] 3.2 In the same section, mark `azure-aks` as a "Bundle" (separate sub-section or a marker on the row) so a novice reading the page can see "if you want AKS, install this one thing" rather than puzzling over which of azure-cli + opentofu they need. Also updated the "When you need a specific tool" row for AKS to point at the new bundle.

### Validation (Phase 3)

- [x] 3.3 `cd website && npm run build` clean for the updated `tools.md`. Per the always-build-locally-before-pushing-docs memory.

---

## Verification gate before merge

- [ ] All Phase 1 validations pass (`bash -n`, listed correctly, fresh-container shows Not installed).
- [ ] Tester closes Phase 2 round (verification script `testing/uis1/talk/tools-install-azure-aks.md` filed alongside this PLAN).
- [ ] Phase 3 docs updated; local Docusaurus build clean.
- [ ] PR description includes the cold-install + warm-re-run + partial-state-re-run outputs from Phase 2 as evidence.

---

## What this PLAN deliberately does NOT do

- **Touch `tool-installation.sh`.** The wrapper handles meta-tools correctly today via the same code path as any other `install-*.sh`. No changes.
- **Add a `META` rendering layer to `./uis tools list`.** Optional polish, not blocking. Leaves a hook (`TOOL_CATEGORY="META"`) for a future PR.
- **Bundle `kubelogin`.** Today's AKS module uses local-account auth; kubelogin is not invoked. See the parent investigation's "Out of Scope" section.
- **Touch any of the four hardened installer scripts** (`install-{azure,aws,gcp}-cli.sh`, `install-opentofu.sh`). They stay as-is; the meta-tool calls into them via `install_tool`.

---

## Related

- [INVESTIGATE-aks-novice-onboarding.md](../backlog/INVESTIGATE-aks-novice-onboarding.md) — parent investigation. Q1 (name), Q2 (delegating-script pattern), Q3 (stop on failure), Q10 (always-have-output) all directly inform this PLAN.
- [PLAN-tool-installer-error-handling.md](./PLAN-tool-installer-error-handling.md) — prerequisite (PR #152, merged 2026-05-10). The contract block + `set -euo pipefail` pattern this PLAN follows comes from there.
- `provision-host/uis/lib/tool-installation.sh:184` — `install_tool` wrapper. Recursion from inside `do_install` works because the subshell at line 213-221 inherits parent functions; no plumbing needed.
- **Next**: [INVESTIGATE-aks-novice-onboarding.md → PLAN #2 — `./uis platform init azure-aks` wizard](../backlog/INVESTIGATE-aks-novice-onboarding.md). The big one. Builds on this PLAN's meta-installer as a preflight check.
