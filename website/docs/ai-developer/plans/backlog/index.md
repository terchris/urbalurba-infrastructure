---
title: Backlog
sidebar_position: 1
---

# Backlog

Investigations and plans waiting for implementation, sorted by last updated date.

| Document | Goal | Updated |
|----------|------|---------|
| [Platform Roadmap](STATUS-platform-roadmap.md) | Track prioritized investigations and planned work for the UIS platform | 2026-04-15 |
| [INVESTIGATE: Version Pinning for Helm Charts and Container Images](INVESTIGATE-version-pinning.md) | Everything works today, but 18 of 21 Helm charts and several container images have no version pinning. Any upstream release — intentional or accidental — can break the system without warning. A single `./uis deploy` could pull a new chart version with breaking changes. | 2026-04-15 |
| [INVESTIGATE: Verification Playbooks Usage and Coverage](INVESTIGATE-verification-playbooks-usage.md) | The `ansible/playbooks/utility/` folder contains a mix of verification playbooks, task includes, setup helpers, and one-off utilities. Several of these files appear to have no active caller in the current repo. | 2026-04-15 |
| [INVESTIGATE: Undeploy --purge flag](INVESTIGATE-undeploy-purge-flag.md) | — | 2026-04-15 |
| [Investigate: UIS Connect Commands for All Services](INVESTIGATE-uis-connect-commands.md) | Design and build `uis connect <service>` commands that open interactive clients into deployed services without requiring clients in the uis-provision-host image. | 2026-04-15 |
| [Investigate: Version Metadata in Service Scripts](INVESTIGATE-service-version-metadata.md) | Decide how service scripts should expose version information for docs generation and CLI display | 2026-04-15 |
| [INVESTIGATE: Remote Deployment Targets & Target Management](INVESTIGATE-remote-deployment-targets.md) | — | 2026-04-15 |
| [INVESTIGATE: Provision-Host Tools and Provider Authentication](INVESTIGATE-provision-host-tools-and-auth.md) | — | 2026-04-15 |
| [INVESTIGATE: Platform Provisioning Layer](INVESTIGATE-platform-provisioning-layer.md) | — | 2026-04-15 |
| [INVESTIGATE: Migrate Host Documentation to UIS CLI](INVESTIGATE-host-docs-migration.md) | — | 2026-04-15 |
| [Investigate: Fix Gravitee Deployment](INVESTIGATE-gravitee-fix.md) | Get Gravitee working and aligned with UIS patterns — it was broken before the service migration and has never been verified | 2026-04-15 |
| [Investigate: First UIS Stack Template](INVESTIGATE-first-uis-template.md) | Decide which UIS stack template to create first, then build it as the reference implementation for `uis template`. | 2026-04-15 |
| [Notes for installing EspoCRM in UIS](INVESTIGATE-espocrm.md) | — | 2026-04-15 |
| [Investigate: Enonic Content Deployment](INVESTIGATE-enonic-content-deployment.md) | Determine how content (data) moves between Enonic environments and whether it can be automated | 2026-04-15 |
| [Investigate: Enonic App Deployment Pipeline](INVESTIGATE-enonic-app-deployment-pipeline.md) | Design and implement a pull-based pipeline for deploying Enonic apps (JAR files) into the Enonic XP instance running in UIS | 2026-04-15 |
| [Investigate: Docs Markdown Generator Update Logic](INVESTIGATE-docs-markdown-update-logic.md) | Add logic to `uis-docs-markdown.sh` to update metadata-driven sections of existing markdown pages without overwriting manually written content | 2026-04-15 |
| [Investigate: DCT One-Command ArgoCD Deployment](INVESTIGATE-dct-argocd-deploy.md) | Enable a developer to deploy their current project to the UIS Kubernetes cluster from inside the DCT devcontainer with a single command. | 2026-04-15 |
| [Investigate: UIS Container Pull Command](INVESTIGATE-container-pull-command.md) | Add a `./uis pull` command that pulls the latest provision-host container image and restarts the container | 2026-04-15 |
| [Investigate: Backstage Developer Portal for UIS](INVESTIGATE-backstage.md) | Deploy Backstage as the developer portal for UIS, modeling all existing services in a software catalog | 2026-04-15 |
| [Investigate: Backstage Enhancements](INVESTIGATE-backstage-enhancements.md) | Evaluate and prioritize additional Backstage features beyond the initial deployment (PLAN-002) | 2026-04-15 |
| [Investigate: Backstage Authentik OIDC Authentication](INVESTIGATE-backstage-auth.md) | Investigate adding Authentik OIDC authentication to Backstage (replacing guest access) | 2026-04-15 |
| [INVESTIGATE: Authentik User Config Migration](INVESTIGATE-authentik-user-config.md) | User-configurable Authentik data (test users, domains, protected services, OAuth apps) is hardcoded in `manifests/` where users shouldn't be editing files. This data should live in `.uis.extend/` so users can customize their setup without touching infrastructure code. | 2026-04-15 |
