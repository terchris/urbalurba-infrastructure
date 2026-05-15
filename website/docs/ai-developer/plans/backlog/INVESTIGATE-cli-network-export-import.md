---
status: backlog
created: 2026-05-13
source: talk52 F10 (UIS-USER1 Message 12)
related:
  - PLAN-network-cloudflare-port-and-docs-lift-up.md
---

# INVESTIGATE: `uis network export/import <provider>` for portable provider state

## Problem

`uis network init <provider>` writes credentials to two host files:

- `.uis.secrets/service-keys/<provider>.env` — the canonical record
- `.uis.secrets/secrets-config/00-common-values.env.template` — patched lines for the secrets pipeline

Both survive container recycles (host bind mount), but neither survives:

- Deleting the test folder
- Cloning to a fresh test folder for clean-state re-verification
- Anyone picking up the work on a different machine

In practice, every fresh clone or test-folder reset re-pays the dashboard-and-token ceremony (~20–45 min for Cloudflare per talk52 F6/F7/F9). The Cloudflare-side state (tunnel, hostname routes, DNS records) is persistent — but the local cred files are not.

The talk52 tester's workaround:

```bash
# After init, copy the canonical env file to a stable location
mkdir -p ~/.uis-state/cloudflare-<tunnel-name>
cp .uis.secrets/service-keys/cloudflare.env ~/.uis-state/cloudflare-<tunnel-name>/
chmod 600 ~/.uis-state/cloudflare-<tunnel-name>/cloudflare.env

# On a fresh test folder, restore + deploy
cp ~/.uis-state/cloudflare-<tunnel-name>/cloudflare.env <newfolder>/.uis.secrets/service-keys/
cd <newfolder>
./uis network up cloudflare
```

That works (the env file alone is enough — `up.sh` chains `uis secrets generate` which re-patches the master template), but it's a manual step the user has to remember and a path UIS doesn't sanction.

## Proposed shape

Two new subcommands under `uis network`:

| Command | Behavior |
|---|---|
| `uis network export <provider> [--out <path>]` | Bundle the per-provider env file + the matching `00-common-values.env.template` lines into a portable file (default: `~/.uis-state/<provider>-<name>/<provider>.env`). Optional `--encrypt` flag to passphrase-protect. |
| `uis network import <provider> <path>` | Restore the env file into the current test folder's `.uis.secrets/`, patch the common-values template, and (optionally) chain `uis secrets generate` + `uis secrets apply`. |

Open questions for the investigation:

1. **Scope**: Cloudflare-only, all providers under `networking/`, or generalize to any secrets bundle (`uis state export/import <thing>`)?
2. **Format**: a single env file, or a small bundle with metadata (provider, tunnel-name, created-at, host fingerprint for safety)?
3. **Encryption**: passphrase-based (age, gpg, openssl) — or pin to OS keychain (macOS Keychain / Linux secret-service)?
4. **Default location**: `~/.uis-state/<provider>/<name>/` or `~/.config/uis/state/<provider>/<name>/`? Both are stable per-user; XDG-compliant matters if anyone runs UIS on a multi-tenant box.
5. **Conflict policy on import**: refuse if the target env file exists? Force-overwrite with `--force`? Show a 3-option menu like `uis network init`?

## Out of scope

- Cloudflare-side state export (tunnel UUID, hostname routes, DNS records) — that's on the Cloudflare dashboard and stable. Local-side only.
- Cluster-side secret backup (`urbalurba-secrets` k8s Secret) — already regenerable from the local env files via `uis secrets generate && uis secrets apply`.
- Generalizing to non-network providers (PostgREST JWT secret, db credentials, etc.). That's the "general feature" framing the tester proposed; tackle it as a follow-up if the network-only version proves the pattern.

## Not urgent

The manual workaround is trivial. This investigation matters when:

- A second tester / contributor / customer needs the cloudflare path on their machine
- We start running automated end-to-end tests against a real Cloudflare tunnel (each test run starts from a clean folder)
- The DCT / TMP template-system work surfaces the same "where do the credentials live" question for non-network secrets

Until one of those lands, the workaround documented in talk52 Message 12 is enough.
