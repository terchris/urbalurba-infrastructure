# PLAN-002: Tailscale network CLI port

> **IMPLEMENTATION RULES:** Before implementing this plan, read and follow:
> - [WORKFLOW.md](../../WORKFLOW.md) - The implementation process
> - [PLANS.md](../../PLANS.md) - Plan structure and best practices

## Status: Backlog

**Goal**: Port Tailscale from `uis tailscale expose/unexpose/verify` + `uis deploy tailscale-tunnel` to a first-class `uis network <verb> tailscale` family symmetric with the Cloudflare port (PRs #169–#172), including per-service `expose`/`unexpose` sub-verbs.

**Last Updated**: 2026-05-13

**Investigation**: [INVESTIGATE-tailscale-architecture-cleanup.md](INVESTIGATE-tailscale-architecture-cleanup.md) — Decisions 5, 7, 8, 9, 10, 14; Contracts C-1 through C-11.

**Prerequisites**: [PLAN-001-tailscale-variable-cleanup-and-deletions](PLAN-001-tailscale-variable-cleanup-and-deletions.md) must be complete first.

**Blocks**: PLAN-003-tailscale-docs-lift-up depends on the new CLI surface existing.

**Priority**: High — main user-facing deliverable of the Tailscale architecture-cleanup initiative.

---

## Overview

After PLAN-001 lands the cleanup, this plan builds the new CLI surface. Five core verbs (`init`, `up`, `down`, `status`, `verify`) mirror the Cloudflare port shape; two additional sub-verbs (`expose`, `unexpose`) are Tailscale-specific because per-service Funnel devices are the canonical exposure model (Decision 8 — Tailscale tailnets have no wildcard subdomain DNS, so per-service is the only viable shape for multi-service demos).

A critical user-facing fact this plan must surface (per Decision 10 / C-8): **Tailscale Funnel bypasses Traefik**. The operator's per-service proxy pod forwards directly to the backend Kubernetes Service. Authentik forward-auth, Traefik middleware, and HostRegexp matching do not apply on Tailscale-exposed URLs. The wizard banner, the `expose.sh` first-use prompt, and (in PLAN-003) the `networking/tailscale.md` callout all surface this.

After this plan ships, the new CLI replaces the legacy. `cmd_tailscale` becomes a redirect stub mirroring `cmd_cloudflare`. `tailscale-tunnel` is removed from `services.json`.

---

## Phase 1: Operator install split + core scripts

Decision 5 splits the operator install into its own playbook so it's idempotent and reusable. C-1 through C-4 + C-9 define the four core scripts.

### Tasks

- [ ] 1.1 Create `ansible/playbooks/8XX-tailscale-operator-install.yml` (Decision 5). Idempotent Helm install of `tailscale-operator` in `namespace: tailscale`. Reads `TAILSCALE_CLIENTID` + `TAILSCALE_CLIENTSECRET` + `TAILSCALE_OWNER_ID` (renamed in PLAN-001). The 802/805 collision is moot — 805 is gone (deleted in PLAN-001 Phase 3.4).
- [ ] 1.2 Rename `802-deploy-network-tailscale-tunnel.yml` → `802-tailscale-funnel-ingress.yml`. Strip out the operator install portion (now in 1.1); keep only the cluster Funnel `Ingress` creation. Only invoked when `up --with-cluster-funnel`.
- [ ] 1.3 Create `networking/tailscale/scripts/init.sh` (C-3). 4-prompt wizard:
  - Prompt order: `TAILSCALE_TAILNET`, `TAILSCALE_CLIENTID`, `TAILSCALE_CLIENTSECRET`, `TAILSCALE_OWNER_ID`
  - `OWNER_ID` prompt validates `^[a-z0-9-]+$` and max length 32 chars
  - Banner lists 4 admin-console prereqs (Q5 resolution): OAuth client with right scopes, MagicDNS, Funnel `nodeAttrs`, tailnet name
  - First paragraph surfaces the Traefik-bypass fact (C-8 surfacing #1)
  - 3-option Skip/Re-prompt/Show menu when `.uis.secrets/service-keys/tailscale.env` exists
  - Writes `service-keys/tailscale.env` (mode 0600) AND patches the matching lines in `secrets-config/00-common-values.env.template`; preserves comment blocks intact
- [ ] 1.4 Create `networking/tailscale/scripts/up.sh` (C-2 + C-9 + C-11):
  - Refuse if `TAILSCALE_OWNER_ID` empty (C-9 defensive guard)
  - Detect owner-id change vs running operator (C-11) — refuse with "tear down first" pointer if mismatch
  - Parse `--with-cluster-funnel` flag
  - Chain `uis secrets generate && uis secrets apply`
  - Invoke `ansible-playbook 8XX-tailscale-operator-install.yml`; if `--with-cluster-funnel`, also `802-tailscale-funnel-ingress.yml`
  - Closing banner: operator pod state + cluster Funnel URL (if applicable) + `Next: ./uis network expose tailscale <svc>` hint
- [ ] 1.5 Create `networking/tailscale/scripts/down.sh`:
  - Invoke `ansible-playbook 801-remove-network-tailscale-tunnel.yml` (cleans operator + cluster Funnel + per-service devices + tailnet API device cleanup)
  - Preserve `.uis.secrets/service-keys/tailscale.env` (symmetric to cloudflare)
  - Closing banner: cluster cleanup confirmed + admin-console cleanup hints (revoke OAuth client + delete stale devices) for full retirement
- [ ] 1.6 Create `networking/tailscale/scripts/status.sh` (C-1):
  - Default mode: human-readable summary — operator pod state, list of exposed services with their `<svc>-<owner_id>` device names, cluster Funnel state if deployed
  - `--summary` flag emits `<state>\t<hint>` for `uis network list`. States: `not-initialized | configured-not-running | running | unreachable`
- [ ] 1.7 Create `networking/tailscale/scripts/verify.sh` (C-4). Chains `ansible-playbook 803-verify-tailscale.yml` (which dropped the SECRET check in PLAN-001 Phase 2.6). Exits 0 only when all 5 checks pass.

### Validation

```bash
# Operator install playbook syntax + idempotency dry-run
ansible-playbook ansible/playbooks/8XX-tailscale-operator-install.yml --syntax-check
ansible-playbook ansible/playbooks/802-tailscale-funnel-ingress.yml --syntax-check

# All 5 scripts pass syntax check
for s in init up down status verify; do
  bash -n "networking/tailscale/scripts/$s.sh" && echo "✓ $s.sh OK"
done

# Status --summary contract — empty state should emit "not-initialized\t<hint>"
./networking/tailscale/scripts/status.sh --summary
```

User confirms phase is complete.

---

## Phase 2: Per-service expose / unexpose

Decision 8 ports the legacy per-service shell-script logic into the new scripts namespace. C-7 + C-8 + C-10 define the contract.

### Tasks

- [ ] 2.1 Create `networking/tailscale/scripts/expose.sh` (C-7, C-8, C-10):
  - Argument: service name (`./uis network expose tailscale whoami` → `$1=whoami`)
  - Refuses if operator not deployed (calls `status.sh --summary`, checks for `running` state)
  - Refuses if `kubectl -n default get svc <service>` fails (C-10 — assumes port 80, default namespace)
  - First-use confirmation prompt (C-8 surfacing #3) when no Tailscale-class `Ingress` exists in `default` yet: "This URL will be publicly reachable without Authentik or Traefik middleware. The service itself must enforce auth if needed. Continue? [y/N]". `--yes` flag bypasses.
  - Compute device name: `<service>-<TAILSCALE_OWNER_ID>`
  - Invoke `ansible-playbook 802-tailscale-tunnel-addhost.yml -e service_name=<service> -e device_hostname=<svc>-<owner_id>`
  - Closing banner: device URL `https://<svc>-<owner_id>.<tailnet>.ts.net` + cert provisioning wait time (~15s) + Slack-shareable summary
- [ ] 2.2 Create `networking/tailscale/scripts/unexpose.sh` (C-7):
  - Argument: service name
  - Idempotent: removing a service that isn't exposed is a successful no-op with clear "wasn't exposed" message
  - Delete the matching `Ingress` from `default` namespace
  - Invoke `ansible-playbook 803-tailscale-device-cleanup.yml` to remove the tailnet device via API
- [ ] 2.3 Delete `networking/tailscale/802-tailscale-tunnel-deploy.sh` (Decision 8 — work moved into `up.sh` + `expose.sh`)
- [ ] 2.4 Delete `networking/tailscale/803-tailscale-tunnel-deletehost.sh` (Decision 8 — work moved into `unexpose.sh`)

### Validation

```bash
# Syntax checks
bash -n networking/tailscale/scripts/expose.sh && echo "✓ expose.sh OK"
bash -n networking/tailscale/scripts/unexpose.sh && echo "✓ unexpose.sh OK"

# Confirm deleted legacy scripts are gone
[ ! -f networking/tailscale/802-tailscale-tunnel-deploy.sh ] && echo "✓ 802-deploy.sh deleted"
[ ! -f networking/tailscale/803-tailscale-tunnel-deletehost.sh ] && echo "✓ 803-deletehost.sh deleted"

# Expose refuses cleanly when operator not deployed
./networking/tailscale/scripts/expose.sh whoami 2>&1 | grep -q 'operator not deployed' && echo "✓ expose refuses without operator"
```

User confirms phase is complete.

---

## Phase 3: CLI dispatcher port (`uis-cli.sh`)

C-6 defines the redirect-stub shape. New `cmd_network` subcommands for `expose`/`unexpose`.

### Tasks

- [ ] 3.1 Add `tailscale` to `cmd_network` provider whitelist for `init / up / down / status / verify`. Each dispatches to `networking/tailscale/scripts/<verb>.sh`.
- [ ] 3.2 Add new `cmd_network` subcommands `expose` and `unexpose` (only `tailscale` is a valid provider for these — refuse cleanly for cloudflare with a pointer to the cluster-tunnel model).
- [ ] 3.3 Update `cmd_network_list` — tailscale row now reads real state from `status.sh --summary` (drops the hardcoded `· port pending` placeholder).
- [ ] 3.4 Replace `cmd_tailscale` family (C-6) with a redirect stub mirroring `cmd_cloudflare`:
  ```
  ✗ 'uis tailscale' moved to 'uis network ... tailscale'.
    expose   → ./uis network expose tailscale <svc>
    unexpose → ./uis network unexpose tailscale <svc>
    verify   → ./uis network verify tailscale
  ```
  Exit 1.
- [ ] 3.5 Update `cmd_verify` (around line 1893–95 of `uis-cli.sh`) — the legacy `uis verify tailscale` alias now dispatches to `cmd_network_verify tailscale` (mirrors the cloudflare alias).
- [ ] 3.6 Help text update — add `expose`/`unexpose` to the `Network:` block; remove the `Tailscale (legacy verbs — CLI port to 'network' coming):` section since the work is done.

### Validation

```bash
bash -n provision-host/uis/manage/uis-cli.sh && echo "✓ uis-cli.sh OK"

# Help shows the new shape
./uis help 2>&1 | grep -A 12 "^Network:"
# Expected: init/up/down/status/verify/expose/unexpose for tailscale + cloudflare

# Redirect stubs fire
./uis tailscale expose whoami 2>&1 | grep -q "moved to 'uis network'" && echo "✓ tailscale expose redirects"
./uis tailscale verify 2>&1 | grep -q "moved to 'uis network'" && echo "✓ tailscale verify redirects"
```

User confirms phase is complete.

---

## Phase 4: Service abstraction cleanup

Decision 7 removes `tailscale-tunnel` from `services.json`, mirroring the Cloudflare port pattern.

### Tasks

- [ ] 4.1 Delete the `tailscale-tunnel` entry from `website/src/data/services.json`
- [ ] 4.2 Delete `provision-host/uis/services/networking/service-tailscale-tunnel.sh`
- [ ] 4.3 Update `provision-host/uis/lib/integration-testing.sh` line 28 — remove the `tailscale-tunnel:TAILSCALE_CLIENTID,TAILSCALE_CLIENTSECRET,TAILSCALE_DOMAIN` gate line (service no longer exists via this path; note `TAILSCALE_DOMAIN` is also gone after PLAN-001 Phase 2.2)
- [ ] 4.4 Verify `./uis list` no longer shows `tailscale-tunnel`. `./uis deploy tailscale-tunnel` should error with:
  ```
  [ERROR] Service 'tailscale-tunnel' not found.
          Tailscale moved to './uis network up tailscale' — see './uis help' for the Network section.
  ```
  (Mirrors the cloudflare redirect pattern from PR #169.)

### Validation

```bash
# services.json parses + no tailscale-tunnel entry
python3 -c "import json; data=json.load(open('website/src/data/services.json')); assert not any(s.get('id')=='tailscale-tunnel' for s in data.get('@graph', data) if isinstance(s, dict))"

# Legacy deploy errors with redirect
./uis deploy tailscale-tunnel 2>&1 | grep -q "moved to './uis network up tailscale'" && echo "✓ legacy deploy redirects"
```

User confirms phase is complete.

---

## Phase 5: Local verification

### Tasks

- [ ] 5.1 `cd website && npm run build` — Docusaurus build clean
- [ ] 5.2 `./uis build` to build the local container image with the new CLI
- [ ] 5.3 Cycle the container: `docker stop uis-provision-host; docker rm uis-provision-host; export UIS_IMAGE=uis-provision-host:local; ./uis start`
- [ ] 5.4 Smoke test the new CLI surface (no real cluster touch):
  - `./uis help` — Network section shows the 7 subcommands (init/up/down/status/verify/expose/unexpose), provider list includes cloudflare + tailscale; no leftover `Tailscale:` block
  - `./uis network list` — table shows tailscale row in `· not initialized` state (real, not placeholder)
  - `./uis network init tailscale --help` (or invocation that triggers the banner without going through the prompts) — confirms the 4 admin-console prereqs are listed and the Traefik-bypass callout is present
  - `./uis tailscale expose whoami` — redirect stub fires; non-zero exit
  - `./uis deploy tailscale-tunnel` — service-not-found error with redirect hint

### Validation

```bash
cd website && npm run build 2>&1 | tail -3
# Expected: [SUCCESS] Generated static files in "build".

# Smoke tests above all PASS
```

User confirms phase is complete.

---

## Acceptance Criteria

- [ ] `uis help` shows Network section with 7 subcommands and `tailscale` listed as a provider
- [ ] `uis network list` shows real tailscale state (not the placeholder)
- [ ] All 7 scripts exist under `networking/tailscale/scripts/`: init, up, down, status, verify, expose, unexpose
- [ ] Operator install is a separate playbook (Decision 5), idempotent
- [ ] `uis tailscale expose/unexpose/verify` all fire the redirect stub (C-6)
- [ ] `uis deploy tailscale-tunnel` errors with redirect (Decision 7 mirrors cloudflare)
- [ ] Traefik-bypass fact surfaced in wizard banner + `expose.sh` first-use prompt (C-8 surfacing #1 + #3; #2 is `networking/tailscale.md` which lands in PLAN-003)
- [ ] Local `npm run build` succeeds; `bash -n` clean on all scripts
- [ ] No real cluster work yet (that's the tester verification round, scoped to PLAN-003)

---

## Files to Modify

**Create:**
- `ansible/playbooks/8XX-tailscale-operator-install.yml`
- `networking/tailscale/scripts/init.sh`
- `networking/tailscale/scripts/up.sh`
- `networking/tailscale/scripts/down.sh`
- `networking/tailscale/scripts/status.sh`
- `networking/tailscale/scripts/verify.sh`
- `networking/tailscale/scripts/expose.sh`
- `networking/tailscale/scripts/unexpose.sh`

**Rename:**
- `ansible/playbooks/802-deploy-network-tailscale-tunnel.yml` → `ansible/playbooks/802-tailscale-funnel-ingress.yml`

**Edit:**
- `provision-host/uis/manage/uis-cli.sh` (cmd_network adds tailscale; cmd_network adds expose/unexpose; cmd_tailscale → redirect stub; cmd_verify alias; cmd_network_list reads real summary; help text)
- `provision-host/uis/lib/integration-testing.sh` (drop tailscale-tunnel gate line)
- `website/src/data/services.json` (delete tailscale-tunnel entry)

**Delete:**
- `provision-host/uis/services/networking/service-tailscale-tunnel.sh`
- `networking/tailscale/802-tailscale-tunnel-deploy.sh`
- `networking/tailscale/803-tailscale-tunnel-deletehost.sh`

---

## Implementation Notes

- **Mirror `cmd_cloudflare` shape precisely.** The redirect-stub pattern, the wizard structure, the script entry points, the `_uis_cluster_banner` walk-in/walk-out per verb — all of it should match the Cloudflare port. Reviewers familiar with PRs #169–#172 should find the diff structurally familiar.
- **C-10 is intentionally narrow.** `expose.sh` assumes `default` namespace + port 80 because that's what every UIS-deployed service uses today. If a real use case for non-default port or namespace surfaces, add `--port` / `--namespace` flags in a follow-up. Don't pre-build.
- **C-11 (owner-id-change detection) is the only piece that's genuinely new logic.** Decisions 13 + 14 made owner-id the cross-cutting identity; if the user changes it after deploy, the cluster's operator and tailnet devices are still under the old name. The detection compares env-file value vs the operator's actual device name annotation. Implementation: read the operator Deployment's pod template label or annotation; bail if mismatch with a clear pointer to `down` first.
- **Tester verification round is scoped to PLAN-003**, not here. PLAN-002 ends at local smoke tests against `:local` image. The real cluster work (init → up → expose → curl from phone → unexpose → down) waits for PLAN-003.
