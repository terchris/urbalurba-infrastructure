# Investigate: Add an email/SMTP capability to UIS

> **IMPLEMENTATION RULES:** Before implementing this plan, read and follow:
> - [WORKFLOW.md](../../WORKFLOW.md) - The implementation process
> - [PLANS.md](../../PLANS.md) - Plan structure and best practices

## Status: Backlog

**Goal**: Provide a single, project-wide way to send email from UIS-deployed services. Today no UIS service can send email because there is no SMTP relay deployed in the cluster and no shared `SMTP_*` configuration in the secrets layer. This blocks user-onboarding flows in several services we already ship (and several we plan to add). Decide whether to host an SMTP relay inside UIS (dev-only catcher, prod-ish relay) or to point all services at an external provider via shared SMTP credentials, then wire up the chosen pattern once so every service consumes it the same way.

**Last Updated**: 2026-05-02

**Request origin**: Surfaced during the post-merge config audit of Gravitee APIM 4.11. The browser tester noted that the Gravitee Console SMTP settings show the chart's placeholder host (`smtp.my.domain`, port 587) and that any flow needing email — user invites, subscription approvals, password resets — will silently fail. While digging into a Gravitee-specific fix, we recognised the problem is shared across services. The contributor agreed it should be solved once at the UIS layer rather than per-service.

**Depends on**: nothing hard. Touches the secrets-template layer (`provision-host/uis/templates/secrets-templates/00-master-secrets.yml.template` + `00-common-values.env.template`), one new manifest (or an external-provider config), and per-service config files that should consume the shared values.

---

## Why this matters

Multiple services already shipping in UIS expect SMTP to be configured and degrade silently when it is not:

| Service | What email is used for | Current state |
|---|---|---|
| Gravitee APIM | User invites, API subscription approvals, password resets | Chart placeholder `smtp.my.domain` — emails dropped |
| Authentik | Password reset, email verification, account recovery | `AUTHENTIK_BOOTSTRAP_EMAIL` set; SMTP unconfigured |
| Nextcloud | Share notifications, password reset, calendar invites | unconfigured |
| OpenMetadata | Account email + outbound notifications | `OPENMETADATA_ADMIN_EMAIL` set; SMTP unconfigured |
| Backstage (planned) | Catalog/notification plugin | unconfigured |
| Argo CD (planned, EE notif controller) | Sync failure alerts | unconfigured |
| Future: Gitea, Jira-likes, etc. | Standard | will need it |

There is currently no shared `SMTP_HOST`, `SMTP_PORT`, `SMTP_USER`, `SMTP_PASSWORD`, `SMTP_FROM_ADDRESS` in `00-common-values.env.template` or a shared `smtp` block in `00-master-secrets.yml.template`, so each service either uses chart defaults (which point at non-existent placeholder hosts) or has its email layer disabled by default. Anyone trying a "real" workflow on one of these services hits the same wall.

This investigation should pick a pattern and apply it once.

---

## Options

Three viable patterns. Pick one.

### Option A — In-cluster dev catcher (MailHog / MailDev / Mailpit)

Deploy a tiny SMTP server inside UIS that **catches all outbound mail and exposes it on a web UI** so a developer can read what was sent without anything ever leaving the cluster. Exact same API as a real relay (port 1025/SMTP, port 8025/HTTP UI for Mailpit), so services consume it via the standard `SMTP_*` env vars.

**Pros:**
- Zero external dependency, zero cost, zero risk of leaking dev credentials/test addresses out into the world.
- Lets contributors *see* what each service emits without needing a real mailbox.
- Same wire protocol as production, so swapping later is a one-line config change.
- Mailpit (recommended) ships an HTTP search/replay UI suitable for testing flows like "Authentik sends a password reset, click the link in Mailpit".
- Resource footprint: ~30 MB RAM, single replica, no PVC required for dev (in-memory).

**Cons:**
- No real email actually leaves the cluster. Useless for any flow that needs a tester to receive email outside the dev box (rare on UIS but worth noting).
- One more service to maintain, even if it's tiny.

**Recommended image:** `axllent/mailpit:latest` (active, modern Go binary, single container, native SMTP+HTTP+search). Alternatives MailHog (unmaintained since 2020) and MailDev (Node, heavier).

### Option B — External SMTP relay via shared credentials

Don't run a server. Add `SMTP_HOST/PORT/USER/PASSWORD/FROM_ADDRESS` to the secrets layer with sane placeholders, and point every service at them. The user fills in real values for either:
- Their personal Gmail/Outlook relay (app-password based, ~free).
- A SaaS relay (SendGrid, Mailgun, Amazon SES, Postmark) with a free dev tier.
- Their own corporate Postfix/Exchange.

**Pros:**
- Real email actually arrives in real inboxes.
- No new pod, no new cluster surface, no maintenance.
- Production-shaped: whatever pattern works on a laptop also works when UIS deploys to a real environment.

**Cons:**
- Requires a real account and credentials *for every developer who wants email to work*. Many will skip configuration, leaving the same silent-failure mode we have today (just with our own placeholders this time, not Gravitee's chart defaults).
- Gmail-via-app-password has gotten messier over time (2FA required, app passwords for "less secure" apps deprecated for non-Workspace accounts) — fewer dev-friendly free options than there used to be.
- Outbound SMTP from a laptop is sometimes blocked by ISPs without a relay account.

### Option C — Both: in-cluster catcher by default, external relay opt-in

Ship Mailpit as the default SMTP target in `00-master-secrets.yml.template` (`SMTP_HOST=mailpit.mailpit.svc.cluster.local`, `SMTP_PORT=1025`, no auth). Document an opt-in path in `gravitee.md` / `authentik.md` etc. to override `SMTP_*` per-namespace if a developer wants to wire a real provider for that service.

**Pros:**
- Out-of-the-box experience: `./uis deploy gravitee` → admin sends an invite → developer reads it in Mailpit's web UI. No external account needed, no silent-drop, no setup friction.
- Real-relay path is still available to developers who care.
- Matches the broader UIS philosophy: "everything works on a laptop without a cloud account, but production-shaped configs make the jump to real infra trivial."

**Cons:**
- Two paths to support and document.
- Slightly more work upfront than B.

---

## Recommendation (to be confirmed)

**Option C.** Default to Mailpit so the platform is usable out-of-the-box, with a documented escape hatch to swap in real SMTP. This matches how UIS handles other "you'd-need-a-cloud-account-otherwise" capabilities (Gateway TLS, object storage, etc.).

Approximate work breakdown for C:

1. **New manifest** `manifests/0XX-mailpit.yaml` (deployment + service + IngressRoute for the web UI at `mail.localhost`). No PVC needed for dev; everything in memory. ~50 lines.
2. **Service registration** in `provision-host/uis/services/integration/service-mailpit.sh` + `services.json` so it's enableable like any other service.
3. **Shared secrets** added to `00-master-secrets.yml.template` (top-level / global block):
   ```yaml
   SMTP_HOST: "mailpit.mailpit.svc.cluster.local"
   SMTP_PORT: "1025"
   SMTP_FROM_ADDRESS: "${DEFAULT_ADMIN_EMAIL}"
   SMTP_USER: ""           # mailpit accepts unauthenticated
   SMTP_PASSWORD: ""
   ```
   Each consuming namespace then references these (or copies them in) the same way `GRAVITEE_POSTGRES_*` does today.
4. **Per-service wiring** in the existing services that currently ship with SMTP unconfigured:
   - Gravitee: chart values block under `notifiers.email` or similar — needs research, not all knobs are obvious.
   - Authentik: blueprint values for the global SMTP block.
   - OpenMetadata: config map env vars.
   - Nextcloud (when added): occ command or config.php overrides.
5. **Docs**:
   - Per-service "Email" section linking back to the central pattern.
   - Top-level page (e.g. `website/docs/services/integration/mailpit.md`) explaining the dev-catcher pattern, how to read mail, how to swap in a real relay.

Estimated effort: ~half a day for the manifest + secrets + Gravitee + Authentik wiring; another half-day to do the rest of the services that need it. Per-service work is small once the pattern exists.

---

## Open questions

- **Do we want "mail.localhost" as a public service surface, or restrict to provision-host only?** Mailpit is a leak risk if something else is wired through it (it accepts all mail). Recommendation: deploy with no auth, but require authentication or hide behind Authentik forward-auth if exposed externally.
- **What happens when a developer wants real email for *some* services and Mailpit for others?** Probably: per-namespace `SMTP_*` overrides win over the global ones. Keep the cross-namespace plumbing flat so this works without surgery.
- **Should `DEFAULT_ADMIN_EMAIL`'s placeholder change?** It's currently `admin@example.com`. With Mailpit, that's fine — Mailpit accepts anything. But once a real relay is wired, sending to `admin@example.com` is a black hole. Worth noting in the docs.
- **Long-term: are we replacing this with the platform's own notification stack (Argo notifications, Authentik events, etc.)?** SMTP is the lowest-common-denominator. A future plan might push for everything-via-webhook + a single notification gateway. Out of scope here.

---

## Existing email-adjacent state in UIS (before this plan)

For grep-searchability:

```
manifests/075-authentik-config-manual.yaml          AUTHENTIK_BOOTSTRAP_EMAIL (admin email only — no SMTP)
manifests/340-openmetadata-config.yaml              OPENMETADATA_ADMIN_DEFAULT_EMAIL (admin email only — no SMTP)
manifests/090-gravitee-config.yaml                  no SMTP block; chart defaults to placeholder smtp.my.domain
provision-host/uis/templates/secrets-templates/
    00-master-secrets.yml.template                  no SMTP_* keys defined
    00-common-values.env.template                   DEFAULT_ADMIN_EMAIL only
```

Nothing needs to be removed; this plan only adds a coherent SMTP layer that the existing services + future services can opt into.

---

## Out of scope

- Per-service template-customisation of email content (Authentik notification templates, Gravitee invite copy, etc.). Belongs in each service's own plan.
- DKIM / SPF / DMARC / outbound deliverability tuning. Real-relay concern, not solved by this investigation.
- Inbound email (parsing replies into ticketing systems). Different problem domain.
