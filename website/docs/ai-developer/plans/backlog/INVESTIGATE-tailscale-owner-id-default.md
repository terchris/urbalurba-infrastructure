# INVESTIGATE: `TAILSCALE_OWNER_ID` default needs to be developer-unique

**Status:** Investigation needed
**Created:** 2026-05-13
**Surfaced by:** talk52 Obs A (Tailscale architecture cleanup verification)
**Related to:** [INVESTIGATE-tailscale-architecture-cleanup](INVESTIGATE-tailscale-architecture-cleanup.md), PLAN-002 (Tailscale network CLI port), PLAN-003 (Tailscale docs lift-up)

---

## Problem Statement

`TAILSCALE_OWNER_ID` defaults to `k8s` in the secrets template. The variable's semantic (per the architecture-cleanup investigation Decision 13) is "the cluster's owner identity on the shared tailnet" — that's a per-developer / per-machine identifier, not a service-type label. The default value contradicts the semantic.

## Failure Mode at Scale

Two developers on the same tailnet, both running `./uis deploy tailscale-tunnel` against UIS for the first time without overriding the default:

1. **First deploy** — registers `k8s.<tailnet>.ts.net` + `k8s-tailscale-operator.<tailnet>.ts.net`
2. **Second deploy** — name collision. Tailscale resolves by appending `-1`: `k8s-1` + `k8s-tailscale-operator-1`
3. **`./uis tailscale verify`** reports the `-1` device under "Stale Devices" — even though it's a *legitimate, working* device. The "stale" check was designed for actual leftovers from torn-down deploys.

Confusing failure mode for the second developer.

## Existing Evidence on the User's Own Tailnet

From the `businessmodel.io` tailnet — the user has already manually adopted per-machine OWNER_IDs:

```
k8s-imac           + k8s-imac-tailscale-operator        ← OWNER_ID=k8s-imac
k8s-tecmacdev      + k8s-tecmacdev-tailscale-operator   ← OWNER_ID=k8s-tecmacdev
k8s-terje          + k8s-terje-tailscale-operator       ← OWNER_ID=k8s-terje
rancher-desktop    + rancher-desktop-tailscale-operator ← OWNER_ID=rancher-desktop
```

So the right pattern is already in use; just not the default.

## Rejected: `hostname -s`

Inside the rancher-desktop VM, `hostname -s` returns `lima-rancher-desktop` for every user — same collision problem at a different name. Anything intrinsic to the deploy environment fails the same way.

## Proposed: Derive from `GITHUB_USERNAME`

`GITHUB_USERNAME` already exists in the common-values template — it's used for ghcr authentication, so users already have a strong reason to fill it in. Default the master template's Tailscale section to derive from it:

```yaml
# 00-master-secrets.yml.template
TAILSCALE_OWNER_ID: "${TAILSCALE_OWNER_ID:-k8s-${GITHUB_USERNAME}}"
```

Behavior:
- `GITHUB_USERNAME=terchris`, `TAILSCALE_OWNER_ID` blank → renders `k8s-terchris`
- `TAILSCALE_OWNER_ID=k8s-terchris-mbp` set explicitly → override wins (multi-machine)
- Both blank → renders `k8s-` (broken) — validation below catches this

## Required Validation Guards

**Check 1 — `GITHUB_USERNAME` is not the placeholder.**

```bash
if [[ "$GITHUB_USERNAME" == "your-github-username" ]]; then
    fail "GITHUB_USERNAME is still the template placeholder. Set it in common-values.env.template."
fi
```

**Check 2 — `OWNER_ID` resolves to a legal hostname segment.** Tailscale device names allow only `[a-z0-9-]`, no leading/trailing hyphen, max 63 chars. GitHub usernames are nearly that shape (alphanumeric + hyphens, max 39 chars), but allow uppercase which hostnames don't. Lowercase before validating:

```bash
gh_user_lc="$(printf '%s' "$GITHUB_USERNAME" | tr '[:upper:]' '[:lower:]')"
if [[ ! "$gh_user_lc" =~ ^[a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?$ ]]; then
    fail "GITHUB_USERNAME '$GITHUB_USERNAME' is not a legal hostname segment.
          Must be 1-63 chars of [a-z0-9-], not starting or ending with a hyphen."
fi
TAILSCALE_OWNER_ID="${TAILSCALE_OWNER_ID:-k8s-$gh_user_lc}"
```

**Where the checks fire:**
- `./uis secrets validate` — soft-warn (matches the existing `DEFAULT_*` placeholder pattern)
- `./uis deploy tailscale-tunnel` (and future `./uis network up tailscale`) — hard-fail before any device registration. Bad ID causes operational pain; cheap to fail fast.

## Implementation Notes

- **The wizard work belongs in PLAN-002.** The wizard prompts for `TAILSCALE_OWNER_ID` (per architecture-cleanup Decision 14); it should also prompt for / derive from `GITHUB_USERNAME` if not already set, validate both values, and write the resolved ID to common-values.
- **The docs work belongs in PLAN-003.** The OWNER_ID semantic + the GITHUB_USERNAME dependency need explanation in the Tailscale setup docs.
- **The validation guards can land independently.** Two `if` blocks in `./uis secrets validate` + the deploy path — no wizard dependency. Can land alongside PLAN-001 or as a standalone PR if priority warrants.

## Outcomes / What This Investigation Should Decide

1. Confirm the GITHUB_USERNAME-derivation approach (vs. alternatives — explicit prompt only, `git config user.email` parsing, etc.)
2. Decide whether the validation guards land standalone or are folded into PLAN-002
3. Confirm the `k8s-` prefix is wanted (vs. bare `${GITHUB_USERNAME}`) — the prefix makes the cluster-context obvious in the Tailscale admin console listing
4. Decide migration path for existing users with `TAILSCALE_OWNER_ID=k8s` — auto-warn on next deploy? Hard-fail with migration instructions? Leave silently working?
