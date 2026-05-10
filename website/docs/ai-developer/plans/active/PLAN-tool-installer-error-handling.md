# Plan: Harden `./uis tools install` scripts — fail loudly, run repeatedly

> **IMPLEMENTATION RULES:** Before implementing this plan, read and follow:
> - [WORKFLOW.md](../../WORKFLOW.md) - The implementation process
> - [PLANS.md](../../PLANS.md) - Plan structure and best practices

## Status: Active

**Goal**: Make every `provision-host/uis/tools/install-*.sh` script (a) safely re-runnable any number of times and (b) return a non-zero exit code if any installation step fails — including silent failures inside piped `curl | bash` invocations and sequential `apt-get` commands.

**Last Updated**: 2026-05-10

**Related**:
- [PLAN-tools-docs.md](./PLAN-tools-docs.md) — user-facing tools reference, same set of scripts.
- Surfaced during the AKS novice-onboarding refactor: a robust `./uis tools install azure-cli && ./uis tools install opentofu` is a prerequisite for the "minimum-commands" novice flow.

---

## Problem Summary

`./uis tools install <tool>` calls into per-tool scripts at `provision-host/uis/tools/install-<id>.sh`. The wrapper at `provision-host/uis/lib/tool-installation.sh:184` (`install_tool`) does two things well:

1. **Idempotency check** at line 194-197: if `is_tool_installed` already returns 0, the script is skipped with a warning. So re-running `./uis tools install azure-cli` on an already-installed system is a no-op. ✅
2. **Post-install verification** at line 226: re-runs the tool's `TOOL_CHECK_COMMAND` after `do_install` returns. If the binary still isn't on `$PATH`, the wrapper returns 1. ✅

The gap is inside the four `do_install` bodies. **None of them use `set -euo pipefail`**, all four have at least one of these failure-masking patterns, and `return $?` at the end captures only the last command's exit code:

| Script | `set -e`/`pipefail` | `curl \| bash` pipe | Sequential `apt-get` (no `&&`/`set -e`) | `curl -f` |
|---|---|---|---|---|
| `install-aws-cli.sh` | ❌ | — (uses tmpfile) | mixed (some `&&`, some not) | ❌ (`curl -sL`) |
| `install-azure-cli.sh` | ❌ | ✅ (line 38) | ✅ (lines 23-34) | ❌ (`curl -sL`) |
| `install-gcp-cli.sh` | ❌ | ✅ (lines 26, 39) | ✅ (lines 22-44) | ❌ (`curl ...`) |
| `install-opentofu.sh` | ❌ | ✅ (lines 25, 28) | n/a (single pipe) | ✅ (`-fsSL`) |

### What this means in practice

- A failed `apt-get update` (broken signature, network blip) doesn't stop the script — install continues against stale repo metadata.
- `curl https://... | bash` where `curl` fails silently still exits 0, because the shell sees only `bash`'s exit code (which gets EOF and exits clean).
- `curl -sL` without `-f` returns success even on HTTP 404 — you end up piping an HTML error page into `bash` or `gpg --dearmor`.
- The wrapper's post-install check only catches the **terminal** failure (binary missing). It can't catch "installed but to a stale version" or "installed but apt sources file is half-written".
- For idempotent re-runs the wrapper-level `is_tool_installed` short-circuit means re-runs are already safe **today**, but if the first install partially failed and somehow left the binary present, the wrapper skips the re-run that might have repaired it.

---

## Out of Scope

- **Legacy `hosts/install-*.sh` scripts** (`hosts/install-rancher-kubernetes.sh`, `hosts/install-azure-aks.sh`, `hosts/install-azure-microk8s-v2.sh`, `hosts/install-multipass-microk8s.sh`, `hosts/raspberry-microk8s/install-raspberry.sh`) — these are queued for deletion or migration in [INVESTIGATE-migrate-hosts-to-platforms.md](../backlog/INVESTIGATE-migrate-hosts-to-platforms.md). Do not touch in this PR.
- **`do_uninstall` bodies** — same scripts have parallel uninstall functions with the same pattern. Inside this PR's scope to fix consistently *if* the diff stays small; otherwise can split.
- **Adding new tools** (e.g. `kubelogin` as a first-class tool, `helm` plugins). Separate work.
- **Changing the wrapper** (`tool-installation.sh`). Wrapper-level guarantees are already adequate; this plan only hardens the scripts it dispatches to.

---

## Phase 1: Standardize the do_install pattern

Apply a consistent shape to all four `do_install` functions:

```bash
do_install() {
    set -euo pipefail
    echo "Installing <Tool>..."
    ...
}
```

Specifically:

1. `set -euo pipefail` at the top of `do_install` (and `do_uninstall` if cheap to add).
2. All `curl` invocations gain `-fsSL` (fail-on-HTTP-error, silent, follow redirects, location). `install-opentofu.sh` already has this; replicate to the other three.
3. Sequential `apt-get` lines stay as-is once `set -e` is in scope (the failure of `apt-get update` then aborts the script — no need to chain with `&&`).
4. `return $?` at the end becomes redundant (script will have exited non-zero on first failure), but keep it for the success path so the function explicitly returns 0.

### Tasks

- [x] 1.1 `provision-host/uis/tools/install-aws-cli.sh`:
  - Add `set -euo pipefail` to `do_install` and `do_uninstall`.
  - Change `curl -sL "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip"` → `curl -fsSL ...`.
  - Replace `cd "$tmpdir" || exit 1` (the `|| exit 1` is now redundant under `set -e`) with `cd "$tmpdir"`.
  - Restructure cleanup: with `set -e`, the unconditional `cd / && rm -rf "$tmpdir"` after a failed `./aws/install` won't run. Replace with a `trap "rm -rf '$tmpdir'" EXIT` near the top of `do_install`.
  - Capture `local status=$?` after `./aws/install` becomes redundant — drop it; failure auto-aborts.

- [x] 1.2 `provision-host/uis/tools/install-azure-cli.sh`:
  - Add `set -euo pipefail` to `do_install` and `do_uninstall`.
  - Change `curl -sL https://packages.microsoft.com/keys/microsoft.asc` → `curl -fsSL ...`.
  - Change `curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash` → `curl -fsSL https://aka.ms/InstallAzureCLIDeb | sudo bash` (now safe under `pipefail`).

- [x] 1.3 `provision-host/uis/tools/install-gcp-cli.sh`:
  - Add `set -euo pipefail` to `do_install` and `do_uninstall`.
  - Change `curl https://packages.cloud.google.com/apt/doc/apt-key.gpg` (both root and sudo branches) → `curl -fsSL ...`.

- [x] 1.4 `provision-host/uis/tools/install-opentofu.sh`:
  - Add `set -euo pipefail` to `do_install` and `do_uninstall`. (`curl -fsSL` already in place.)

### Validation (Phase 1)

Each script, after the change, satisfies all four:

1. `bash -n install-<tool>.sh` parses cleanly.
2. `shellcheck install-<tool>.sh` runs without new warnings (existing warnings excluded from regression bar; this PR doesn't aim to be a full lint pass).
3. Source the script in an isolated bash and verify `set -euo pipefail` is active inside `do_install`:
   ```bash
   ( source install-azure-cli.sh; do_install_test() { do_install; }; set | grep -E '^(BASH_OPTS|SHELLOPTS)='; )
   ```
4. Forced-failure test: temporarily replace one `curl` URL with a 404 path, re-run `./uis tools install <id>`, confirm exit code is non-zero and a clear error is logged.

---

## Phase 2: Re-run safety verification

Verify that re-running `./uis tools install <id>` on an already-installed tool is a fast, idempotent no-op (this is *already* the wrapper's behavior; Phase 2 just documents and tests it).

### Tasks

- [ ] 2.1 In a clean container, run `./uis tools install azure-cli` once → confirm success and `command -v az` resolves.
- [ ] 2.2 Run `./uis tools install azure-cli` a second time → confirm the wrapper logs `azure-cli is already installed` (line 195 in `tool-installation.sh`) and returns 0 within ~1s (no re-download).
- [ ] 2.3 Repeat 2.1-2.2 for `aws-cli`, `gcp-cli`, `opentofu`.
- [ ] 2.4 Negative case: simulate a partially-failed install (e.g., delete `/etc/apt/sources.list.d/azure-cli.list` but leave the `az` binary), re-run install, verify the wrapper still skips because `command -v az` succeeds. Document this behavior in the PR description as "the wrapper trusts the binary, not the apt state — this is acceptable, the user can `./uis tools uninstall && install` to force a full redo."

### Validation (Phase 2)

End-to-end manual run by tester via `talk.md`:

```bash
docker exec -it provision-host bash
./uis tools install azure-cli   # cold install
./uis tools install azure-cli   # warm re-run — should log "already installed" and exit 0
./uis tools install opentofu    # cold install
./uis tools install opentofu    # warm re-run
which az tofu                    # both resolve
az version                       # actual binary works
tofu version                     # actual binary works
```

---

## Phase 3: Document the contract in the script header

Add a one-block header comment to each `install-*.sh` declaring the contract that the wrapper relies on:

```bash
# Contract:
#   - do_install MUST exit non-zero on any failure (uses set -euo pipefail).
#   - do_install is invoked in a subshell; safe to use cd, traps, env mutations.
#   - Idempotency is enforced at the wrapper level (tool-installation.sh:194)
#     by checking TOOL_CHECK_COMMAND before invocation. Scripts do not need
#     their own "already installed" guard.
```

### Tasks

- [x] 3.1 Add the header block to all four scripts (right under the existing `# === Tool Metadata ===` block).

### Validation (Phase 3)

Each of the four scripts has the contract block. The block is identical across all four (so future scripts can be created by copy-paste of this template).

---

## What this plan deliberately does NOT do

- Doesn't add tests under a CI runner. We don't have a tool-script CI lane today; adding one is a separate "should we lint/test bash scripts in CI" plan.
- Doesn't change the public CLI surface. `./uis tools install <id>` and `./uis tools list` behavior is unchanged from the user's perspective — failures just become loud instead of silent.
- Doesn't add a `--force` re-install flag. The wrapper's "already installed → skip" behavior is the right default; force-reinstall can be a follow-up if anyone hits a real need.
- Doesn't normalize the apt key locations (`/etc/apt/trusted.gpg.d/microsoft.gpg` vs `/usr/share/keyrings/cloud.google.gpg`). They differ by upstream convention; consolidating is unrelated cleanup.

---

## Verification gate before merge

- [ ] All four scripts pass `bash -n` and a manual cold-install run in a fresh provision-host container.
- [ ] `./uis tools list` still renders correctly (it sources script metadata; `set -euo pipefail` inside `do_install` doesn't leak to the metadata read at line 42-54 of `tool-installation.sh`).
- [ ] PR description includes a forced-failure demo (e.g., curl URL changed to a 404, run `./uis tools install azure-cli`, paste the non-zero exit + error message — proves the new behavior).
- [ ] Tester (via `testing/uis1/talk/talk.md` round) confirms cold-install + warm-re-run + cold-install of all four tools.

---

## Related

- [PLAN-tools-docs.md](./PLAN-tools-docs.md) — user-facing tools reference. Touches the same script set; this plan is independent and can land first or second without ordering constraints.
- [INVESTIGATE-migrate-hosts-to-platforms.md](../backlog/INVESTIGATE-migrate-hosts-to-platforms.md) — legacy `hosts/install-*.sh` lifecycle decisions. Out of scope here.
- `provision-host/uis/lib/tool-installation.sh:184` — `install_tool` wrapper that this plan depends on (idempotency check + post-install verification).
