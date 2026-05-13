# PLAN-001: Tailscale variable cleanup and dead-file deletions

> **IMPLEMENTATION RULES:** Before implementing this plan, read and follow:
> - [WORKFLOW.md](../../WORKFLOW.md) - The implementation process
> - [PLANS.md](../../PLANS.md) - Plan structure and best practices

## Status: Active

**Goal**: Shrink the Tailscale secret variable set from 8 to 4 and delete the dead-code files (internal-mode, 801-setup, 804-delete, AUTH_KEY template) ahead of the network CLI port.

**Last Updated**: 2026-05-13

**Investigation**: [INVESTIGATE-tailscale-architecture-cleanup.md](INVESTIGATE-tailscale-architecture-cleanup.md) — Decisions 1, 2, 3, 4, 11, 12, 13, 15, 16.

**Blocks**: PLAN-002-tailscale-network-port-cli cannot start until this is done (new scripts assume the cleaned-up variable namespace).

**Priority**: High — foundation for the rest of the Tailscale architecture-cleanup initiative.

---

## Overview

The existing Tailscale codebase carries architectural debt that accumulated across PLAN-009 / PLAN-010 / PLAN-011 / PLAN-tailscale-variable-rename: 8 partially-overlapping secret variables (some unread), a Helm-release collision between 802 and 805, an orphaned 804 cleanup script, a 805/806 internal-mode path with no CLI verb and silently-broken removal, and an unused `tailscale.env.template` with a 6th variable name (`TAILSCALE_AUTH_KEY`) no code references.

This plan does the "kill what's dead" pass — pure deletions and a single variable rename. The legacy `uis tailscale expose/unexpose/verify` CLI keeps working after this plan ships. No user-facing change beyond `uis deploy tailscale-tunnel` continuing to work against the renamed `TAILSCALE_OWNER_ID` (was `TAILSCALE_OPERATOR_PREFIX`).

After this lands, PLAN-002 builds the new `uis network ... tailscale` CLI surface on the clean foundation.

---

## Phase 1: Rename `TAILSCALE_OPERATOR_PREFIX` → `TAILSCALE_OWNER_ID`

Investigation Decision 13. The new name describes what it means semantically (the cluster's owner on the shared tailnet) rather than its job in one specific Jinja2 template.

### Tasks

- [x] 1.1 `provision-host/uis/templates/secrets-templates/00-common-values.env.template` — rename variable + update the comment block to describe the new owner-id semantic (used for operator device, per-service device names, optional cluster Funnel device name)
- [x] 1.2 `provision-host/uis/templates/secrets-templates/00-master-secrets.yml.template` — rename variable + comment
- [x] 1.3 `ansible/playbooks/802-deploy-network-tailscale-tunnel.yml` — rename in fact extraction + template vars (also lowercase Ansible var `tailscale_operator_prefix` → `tailscale_owner_id`)
- [x] 1.4 `ansible/playbooks/803-verify-tailscale.yml` — confirmed no reference (file gates on CLIENTID/CLIENTSECRET/TAILNET, not OPERATOR_PREFIX)
- [x] 1.5 `manifests/800-tailscale-operator-config.yaml.j2` — rename Jinja2 variable + update example comment block
- [x] 1.6 `networking/tailscale/802-tailscale-tunnel-deploy.sh` — confirmed no reference (the shell wrapper just invokes the playbook)
- [x] 1.7 `website/docs/networking/tailscale-setup.md` + `tailscale-network-isolation.md` — confirmed no reference (will be rewritten in PLAN-003)
- [x] 1.8 `provision-host/uis/lib/integration-testing.sh` — confirmed no reference (Tailscale gate uses CLIENTID/CLIENTSECRET/DOMAIN, not OPERATOR_PREFIX/OWNER_ID)

### Validation

```bash
# Confirm no remaining OPERATOR_PREFIX references in non-historical files
grep -rn 'TAILSCALE_OPERATOR_PREFIX' --exclude-dir=plans/completed --exclude-dir=plans/backlog .
# Expected: empty (or only matches in INVESTIGATE-tailscale-architecture-cleanup.md description text, which is fine)

# Confirm legacy uis deploy tailscale-tunnel still parses + dry-runs (no real cluster touch)
./uis deploy tailscale-tunnel --dry-run
```

User confirms phase is complete.

---

## Phase 2: Delete unused secret variables

Investigation Decisions 2, 3, 11, 12, 16. After this phase, the variable set is down to 4 (`CLIENTID`, `CLIENTSECRET`, `TAILNET`, `OWNER_ID`).

### Tasks

- [ ] 2.1 Delete `TAILSCALE_SECRET` from `00-common-values.env.template` + `00-master-secrets.yml.template` (Decision 2)
- [ ] 2.2 Delete `TAILSCALE_DOMAIN` from both templates (Decision 11). `grep -rn 'TAILSCALE_DOMAIN' .` and replace every read with `TAILSCALE_TAILNET` — files: 802-deploy, 803-verify, plus any shell script readers
- [ ] 2.3 Delete `TAILSCALE_PUBLIC_HOSTNAME` from both templates (Decision 12). Replace every read with `TAILSCALE_OWNER_ID` — files: 801-remove, 802-deploy, 803-verify, 803-tailscale-cluster-ingress.yaml.j2
- [ ] 2.4 Delete `provision-host/uis/templates/uis.secrets/service-keys/tailscale.env.template` entirely (Decision 3 — defines `TAILSCALE_AUTH_KEY`, no code reads it)
- [ ] 2.5 `BASE_DOMAIN_TAILSCALE` cleanup (Decision 16): `grep -rn '\$BASE_DOMAIN_TAILSCALE\|{{ BASE_DOMAIN_TAILSCALE\|{{ base_domain_tailscale' .` — audit each reader, rewire to `${TAILSCALE_TAILNET}` if it actually needs the tailnet domain, delete the read otherwise (Tailscale Funnel bypasses Traefik per Decision 10, so wildcard HostRegexp patterns matching `*.<tailnet>` match nothing in practice). Then delete `BASE_DOMAIN_TAILSCALE` from both templates.
- [ ] 2.6 Update `803-verify-tailscale.yml` to drop the `TAILSCALE_SECRET` placeholder check (was the 6th of 6 checks per investigation; verify still has 5 checks after)

### Validation

```bash
# Confirm no remaining reads of the deleted variables outside historical plans
for v in TAILSCALE_SECRET TAILSCALE_DOMAIN TAILSCALE_PUBLIC_HOSTNAME TAILSCALE_AUTH_KEY BASE_DOMAIN_TAILSCALE; do
  echo "=== $v ==="
  grep -rn "$v" --exclude-dir=plans/completed --exclude-dir=plans/backlog .
done
# Expected: empty for all five

# Confirm template parses cleanly
./uis secrets generate --dry-run
```

User confirms phase is complete.

---

## Phase 3: Delete dead-code files

Investigation Decisions 1, 4, 15.

### Tasks

- [ ] 3.1 Delete `ansible/playbooks/801-setup-network-tailscale-tunnel.yml` (Decision 1 — host-side smoke-test scaffolding, obsolete)
- [ ] 3.2 Delete `networking/tailscale/801-tailscale-tunnel-setup.sh` (Decision 1 — wrapper for the above)
- [ ] 3.3 Delete `networking/tailscale/804-tailscale-tunnel-delete.sh` (Decision 4 — orphaned, 253 lines, no caller, superseded by `801-remove-network-tailscale-tunnel.yml`)
- [ ] 3.4 Delete `ansible/playbooks/805-deploy-tailscale-internal-ingress.yml` (Decision 15 — internal-mode dead)
- [ ] 3.5 Delete `ansible/playbooks/806-remove-tailscale-internal-ingress.yml` (Decision 15 — was silently broken anyway)
- [ ] 3.6 Delete `manifests/805-tailscale-internal-ingress.yaml.j2` (Decision 15)
- [ ] 3.7 Delete `website/docs/networking/tailscale-internal-ingress.md` (Decision 15)
- [ ] 3.8 Update `801-remove-network-tailscale-tunnel.yml` — drop any cleanup logic that assumed 801-setup ran first (host-side state cleanup), keep the cluster-side cleanup
- [ ] 3.9 Update `INVESTIGATE-tailscale-cross-cluster-backbone.md`: replace "Deleted in the cleanup — recoverable from git history" placeholder with the actual commit hash from this plan's PR after merge

### Validation

```bash
# Confirm all listed files are gone
for f in \
  ansible/playbooks/801-setup-network-tailscale-tunnel.yml \
  ansible/playbooks/805-deploy-tailscale-internal-ingress.yml \
  ansible/playbooks/806-remove-tailscale-internal-ingress.yml \
  manifests/805-tailscale-internal-ingress.yaml.j2 \
  networking/tailscale/801-tailscale-tunnel-setup.sh \
  networking/tailscale/804-tailscale-tunnel-delete.sh \
  provision-host/uis/templates/uis.secrets/service-keys/tailscale.env.template \
  website/docs/networking/tailscale-internal-ingress.md; do
  [ ! -e "$f" ] && echo "✓ deleted: $f" || echo "✗ STILL PRESENT: $f"
done

# Confirm legacy uis deploy tailscale-tunnel + uis tailscale expose still work
./uis deploy tailscale-tunnel --dry-run
./uis tailscale expose --help 2>&1 | head -5
```

User confirms phase is complete.

---

## Phase 4: Local verification

### Tasks

- [ ] 4.1 `bash -n` syntax check on all modified shell scripts (no `bash` errors)
- [ ] 4.2 `python3 -c "import json; json.load(open('website/src/data/services.json'))"` — services.json still parses (not touched in this plan, but spot-check)
- [ ] 4.3 `cd website && npm run build` — Docusaurus build clean; no new broken links beyond pre-existing ones in `/plans/`
- [ ] 4.4 Build container locally: `./uis build`
- [ ] 4.5 Smoke test the legacy CLI surface still works (no real cluster work):
  - `./uis help` — Tailscale section still lists `expose/unexpose/verify`
  - `./uis tailscale --help` — usage banner appears
  - `./uis deploy tailscale-tunnel --dry-run` — passes (services.json entry still there at this point)

### Validation

```bash
cd website && npm run build 2>&1 | tail -3
# Expected: [SUCCESS] Generated static files in "build".

bash -n provision-host/uis/manage/uis-cli.sh && echo "uis-cli.sh OK"
# Expected: uis-cli.sh OK
```

User confirms phase is complete.

---

## Acceptance Criteria

- [ ] Variable set is down from 8 to 4: `CLIENTID`, `CLIENTSECRET`, `TAILNET`, `OWNER_ID`
- [ ] Dead files deleted: 801-setup playbook, 801-setup shell wrapper, 804-delete shell, 805/806 playbooks, 805 j2 manifest, AUTH_KEY service-keys template, internal-ingress doc page
- [ ] `TAILSCALE_OPERATOR_PREFIX` references gone from non-historical files
- [ ] `BASE_DOMAIN_TAILSCALE` references gone (rewired to `TAILSCALE_TAILNET` where needed, deleted otherwise)
- [ ] Legacy `./uis deploy tailscale-tunnel` + `./uis tailscale expose/unexpose/verify` still work — this plan does **not** touch the CLI surface
- [ ] Local `npm run build` succeeds
- [ ] `INVESTIGATE-tailscale-cross-cluster-backbone.md` updated with the merge commit hash for the deleted internal-mode files

---

## Files to Modify

**Edit (variable rename + reads):**
- `provision-host/uis/templates/secrets-templates/00-common-values.env.template`
- `provision-host/uis/templates/secrets-templates/00-master-secrets.yml.template`
- `ansible/playbooks/802-deploy-network-tailscale-tunnel.yml`
- `ansible/playbooks/803-verify-tailscale.yml`
- `ansible/playbooks/801-remove-network-tailscale-tunnel.yml`
- `manifests/800-tailscale-operator-config.yaml.j2`
- `manifests/803-tailscale-cluster-ingress.yaml.j2`
- `networking/tailscale/802-tailscale-tunnel-deploy.sh`
- `networking/tailscale/803-tailscale-tunnel-deletehost.sh`
- `website/docs/networking/tailscale-setup.md`
- `website/docs/networking/tailscale-network-isolation.md`
- `website/docs/ai-developer/plans/backlog/INVESTIGATE-tailscale-cross-cluster-backbone.md` (commit hash update)

**Delete:**
- `ansible/playbooks/801-setup-network-tailscale-tunnel.yml`
- `ansible/playbooks/805-deploy-tailscale-internal-ingress.yml`
- `ansible/playbooks/806-remove-tailscale-internal-ingress.yml`
- `manifests/805-tailscale-internal-ingress.yaml.j2`
- `networking/tailscale/801-tailscale-tunnel-setup.sh`
- `networking/tailscale/804-tailscale-tunnel-delete.sh`
- `provision-host/uis/templates/uis.secrets/service-keys/tailscale.env.template`
- `website/docs/networking/tailscale-internal-ingress.md`

---

## Implementation Notes

- **Order matters within Phase 2.** If `TAILSCALE_DOMAIN` reads are replaced with `TAILSCALE_TAILNET` *before* the variable is removed from the templates, the deploy paths keep working; reversing the order leaves a window where deploys fail.
- **`BASE_DOMAIN_TAILSCALE` audit may surface surprises.** It's a cross-cutting variable possibly used in Traefik IngressRoute YAMLs (not just Tailscale playbooks). Be prepared to find readers in unexpected places. If a reader is for a Cloudflare IngressRoute (matching `*.<owned-domain>`), leave it alone — the cleanup target is the Tailscale-side reads only.
- **`INVESTIGATE-tailscale-cross-cluster-backbone.md` commit-hash update** can be done as a follow-up PR if the original PR merges without it; the cross-cluster doc is in backlog and not blocking.
- This plan is **low risk** — pure deletions + a rename. No new code. Legacy CLI unchanged. Should be ~2 hours of mechanical work.
