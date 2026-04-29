---
title: Backlog
sidebar_position: 1
---

# Backlog

Investigations and plans waiting for implementation, sorted by last updated date.

| Document | Goal | Updated |
|----------|------|---------|
| [Platform Roadmap](STATUS-platform-roadmap.md) | Track prioritized investigations and planned work for the UIS platform | 2026-04-29 |
| [Plan: PostgREST deployment (platform service implementation)](PLAN-002-postgrest-deployment.md) | Implement PostgREST as a deployable, multi-instance UIS service following every decision recorded in [INVESTIGATE-postgrest.md](INVESTIGATE-postgrest.md). After this plan, `./uis configure postgrest --app <name>` followed by `./uis deploy postgrest --app <name>` produces a working REST API serving an `api_v1` schema, and the platform supports the multi-instance pattern as a reusable convention. | 2026-04-29 |
| [NOTE — Response to Atlas's PostgREST verification findings (2026-04-28)](NOTE-to-atlas-postgrest-feedback-incorporated.md) | — | 2026-04-29 |
| [NOTE — PostgREST verification findings from Atlas (2026-04-29)](NOTE-from-atlas-postgrest-verification.md) | — | 2026-04-29 |
| [NOTE — PostgREST documentation review: approved (2026-04-29)](NOTE-from-atlas-postgrest-doc-approval.md) | — | 2026-04-29 |
| [INVESTIGATE: Version Pinning for Helm Charts and Container Images](INVESTIGATE-version-pinning.md) | Everything works today, but 18 of 21 Helm charts and several container images have no version pinning. Any upstream release — intentional or accidental — can break the system without warning. A single `./uis deploy` could pull a new chart version with breaking changes. | 2026-04-29 |
| [INVESTIGATE: Verification Playbooks Usage and Coverage](INVESTIGATE-verification-playbooks-usage.md) | The `ansible/playbooks/utility/` folder contains a mix of verification playbooks, task includes, setup helpers, and one-off utilities. Several of these files appear to have no active caller in the current repo. | 2026-04-29 |
| [INVESTIGATE: Undeploy --purge flag](INVESTIGATE-undeploy-purge-flag.md) | — | 2026-04-29 |
| [Investigate: `./uis deploy <service>` semantics for services without a playbook](INVESTIGATE-uis-deploy-no-playbook-semantics.md) | Decide what `./uis deploy <service>` should do when the target service has `SCRIPT_PLAYBOOK=""` (and `SCRIPT_MANIFEST=""`) — the "metadata-only" case introduced when [`service-postgrest.sh`](../../../../../provision-host/uis/services/integration/service-postgrest.sh) shipped without a playbook (PLAN-001 documentation gate; PLAN-002 will add the playbook). | 2026-04-29 |
| [Investigate: UIS Connect Commands for All Services](INVESTIGATE-uis-connect-commands.md) | Design and build `uis connect <service>` commands that open interactive clients into deployed services without requiring clients in the uis-provision-host image. | 2026-04-29 |
| [Investigate: Version Metadata in Service Scripts](INVESTIGATE-service-version-metadata.md) | Decide how service scripts should expose version information for docs generation and CLI display | 2026-04-29 |
| [INVESTIGATE: Remote Deployment Targets & Target Management](INVESTIGATE-remote-deployment-targets.md) | — | 2026-04-29 |
| [INVESTIGATE: Provision-Host Tools and Provider Authentication](INVESTIGATE-provision-host-tools-and-auth.md) | — | 2026-04-29 |
| [Investigate: PostgREST as a UIS service](INVESTIGATE-postgrest.md) | Decide whether and how to package PostgREST as a UIS service that turns a curated PostgreSQL schema into a public REST API, fitting the existing `./uis deploy` flow and the contributor conventions in [`website/docs/contributors/`](../../../contributors/index.md). | 2026-04-29 |
| [INVESTIGATE: Platform Provisioning Layer](INVESTIGATE-platform-provisioning-layer.md) | — | 2026-04-29 |
| [INVESTIGATE: Migrate Host Documentation to UIS CLI](INVESTIGATE-host-docs-migration.md) | — | 2026-04-29 |
| [Investigate: Fix Gravitee Deployment](INVESTIGATE-gravitee-fix.md) | Get Gravitee working and aligned with UIS patterns — it was broken before the service migration and has never been verified | 2026-04-29 |
| [Investigate: First UIS Stack Template](INVESTIGATE-first-uis-template.md) | Decide which UIS stack template to create first, then build it as the reference implementation for `uis template`. | 2026-04-29 |
| [Notes for installing EspoCRM in UIS](INVESTIGATE-espocrm.md) | — | 2026-04-29 |
| [Investigate: Enonic Content Deployment](INVESTIGATE-enonic-content-deployment.md) | Determine how content (data) moves between Enonic environments and whether it can be automated | 2026-04-29 |
| [Investigate: Enonic App Deployment Pipeline](INVESTIGATE-enonic-app-deployment-pipeline.md) | Design and implement a pull-based pipeline for deploying Enonic apps (JAR files) into the Enonic XP instance running in UIS | 2026-04-29 |
| [Investigate: Docs Markdown Generator Update Logic](INVESTIGATE-docs-markdown-update-logic.md) | Add logic to `uis-docs-markdown.sh` to update metadata-driven sections of existing markdown pages without overwriting manually written content | 2026-04-29 |
| [Investigate: DCT One-Command ArgoCD Deployment](INVESTIGATE-dct-argocd-deploy.md) | Enable a developer to deploy their current project to the UIS Kubernetes cluster from inside the DCT devcontainer with a single command. | 2026-04-29 |
| [Investigate: UIS Container Pull Command](INVESTIGATE-container-pull-command.md) | Add a `./uis pull` command that pulls the latest provision-host container image and restarts the container | 2026-04-29 |
| [Investigate: Backstage Developer Portal for UIS](INVESTIGATE-backstage.md) | Deploy Backstage as the developer portal for UIS, modeling all existing services in a software catalog | 2026-04-29 |
| [Investigate: Backstage Enhancements](INVESTIGATE-backstage-enhancements.md) | Evaluate and prioritize additional Backstage features beyond the initial deployment (PLAN-002) | 2026-04-29 |
| [Investigate: Backstage Authentik OIDC Authentication](INVESTIGATE-backstage-auth.md) | Investigate adding Authentik OIDC authentication to Backstage (replacing guest access) | 2026-04-29 |
| [INVESTIGATE: Authentik User Config Migration](INVESTIGATE-authentik-user-config.md) | User-configurable Authentik data (test users, domains, protected services, OAuth apps) is hardcoded in `manifests/` where users shouldn't be editing files. This data should live in `.uis.extend/` so users can customize their setup without touching infrastructure code. | 2026-04-29 |
