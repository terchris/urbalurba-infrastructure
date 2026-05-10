---
title: Active Plans
sidebar_position: 1
---

# Active Plans

Plans currently being implemented. Maximum 1-2 at a time.

| Plan | Goal | Updated |
|------|------|---------|
| [Plan: User-facing tools documentation + cleanup of contributor tools doc](PLAN-tools-docs.md) | Make the tools available inside `uis-provision-host` discoverable from the user-facing parts of the docs (today they're only in `contributors/`), and bring the existing contributor doc into line with reality (currently claims tools are pre-installed, lists `terraform`/`oci`/etc. that aren't actually in the system). | 2026-05-10 |
| [Plan: Harden `./uis tools install` scripts — fail loudly, run repeatedly](PLAN-tool-installer-error-handling.md) | Make every `provision-host/uis/tools/install-*.sh` script (a) safely re-runnable any number of times and (b) return a non-zero exit code if any installation step fails — including silent failures inside piped `curl | bash` invocations and sequential `apt-get` commands. | 2026-05-10 |
| [Plan: Move AKS config to `.uis.secrets/cloud-accounts/azure-default.env`](PLAN-aks-config-cloud-accounts.md) | Replace the bash-file-in-tree config (`platforms/aks/azure-aks-config.sh`) with the documented `.uis.secrets/cloud-accounts/azure-default.env` convention. Single user-edited file; defaults visible inline as commented overrides; scripts use `${VAR:-default}` shell fallback. Aligns AKS with the cluster-secret pattern that `secrets.md` already documents. | 2026-05-10 |
| [Plan: AKS Step 1 — Verify minimal working cluster end-to-end](PLAN-001-aks-step1-verification.md) | Take the unverified `platforms/aks/` OpenTofu drafts (merged 2026-04-09 via PR #120) through their first real end-to-end run against an Azure subscription, fix any gaps that surface, and earn the right to call AKS Step 1 *actually* shipped — by deploying `./uis deploy nginx` against the resulting cluster and watching its built-in connectivity tests pass. | 2026-05-10 |
