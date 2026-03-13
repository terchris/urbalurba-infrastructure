# Platform Roadmap

> **IMPLEMENTATION RULES:** Before implementing this plan, read and follow:
> - [WORKFLOW.md](../../WORKFLOW.md) - The implementation process
> - [PLANS.md](../../PLANS.md) - Plan structure and best practices

## Status: Active

**Goal**: Track prioritized investigations and planned work for the UIS platform

**Last Updated**: 2026-03-13

---

## Open Investigations

Items that still need work, grouped by priority.

### Priority 1: Infrastructure Hardening

| # | Investigation | Status | Summary |
|---|--------------|--------|---------|
| 2 | [Version pinning](INVESTIGATE-version-pinning.md) | Backlog | 18 of 21 Helm charts unpinned. Pin versions to prevent breaking changes. |
| 2b | [Service version metadata](INVESTIGATE-service-version-metadata.md) | Backlog | Decide how service scripts expose version info for docs generation. |
| 3 | [Gravitee fix](INVESTIGATE-gravitee-fix.md) | Backlog | Only unverified service. Hardcoded credentials, no remove playbook, wrong namespace. |

### Priority 2: New Service Deployments

| # | Investigation | Status | Summary |
|---|--------------|--------|---------|
| 5 | [Enonic app deployment pipeline](INVESTIGATE-enonic-app-deployment-pipeline.md) | Investigation complete | Sidecar pulls JARs from GitHub Releases into `$XP_HOME/deploy`. |
| 8 | [Enonic content deployment](INVESTIGATE-enonic-content-deployment.md) | Backlog | Content migration between environments. Manual workflow works initially. |
| 14 | [EspoCRM](INVESTIGATE-espocrm.md) | Backlog | Install EspoCRM CRM platform in UIS. |

### Priority 3: Platform Improvements

| # | Investigation | Status | Summary |
|---|--------------|--------|---------|
| 9 | [Authentik user config](INVESTIGATE-authentik-user-config.md) | Investigation complete | Move user-configurable Authentik data from `manifests/` to `.uis.extend/`. |
| 12 | [Docs markdown update logic](INVESTIGATE-docs-markdown-update-logic.md) | Backlog | `uis-docs-markdown.sh` can only skip or overwrite — no merge/update mode. |
| 15 | [Undeploy --purge flag](INVESTIGATE-undeploy-purge-flag.md) | Backlog | Add `--purge` flag to `./uis undeploy` to delete associated PVCs. |
| 16 | [Verification playbooks usage](INVESTIGATE-verification-playbooks-usage.md) | Backlog | Audit which verification playbooks have active callers. |
| 17 | [Provision-host tools and auth](INVESTIGATE-provision-host-tools-and-auth.md) | Backlog | Tools and authentication setup for provision-host container. |

### Priority 4: Backstage Enhancements

| # | Investigation | Status | Summary |
|---|--------------|--------|---------|
| 18 | [Backstage enhancements](INVESTIGATE-backstage-enhancements.md) | Backlog | Evaluate Scaffolder, TechDocs, Grafana plugin, and other features. Enhancement 1 (API Entities) complete. |
| 19 | [Backstage auth](INVESTIGATE-backstage-auth.md) | Backlog | Add Authentik OIDC authentication to Backstage, replacing guest access. |

### Priority 5: Future Work

Requires real infrastructure or has no immediate need.

| # | Investigation | Status | Summary |
|---|--------------|--------|---------|
| 10 | [Host docs migration](INVESTIGATE-host-docs-migration.md) | Backlog | Legacy host docs describe old deployment approach. Blocked by remote targets. |
| 11 | [Remote deployment targets](INVESTIGATE-remote-deployment-targets.md) | Investigation complete | Azure AKS, Multipass, Raspberry Pi. Needs real infrastructure to test. |

---

## Completed

Items where the work has been implemented.

| # | Investigation / Plan | Completed | Summary |
|---|---------------------|-----------|---------|
| 1 | [Elasticsearch upgrade](../completed/INVESTIGATE-elasticsearch-upgrade.md) | 2026-03-09 | ES 8.5.1 → 9.3.0. [PLAN](../completed/PLAN-elasticsearch-upgrade.md) |
| 4 | [Enonic XP deployment](../completed/INVESTIGATE-enonic-xp-deployment.md) | 2026-03-10 | CMS platform, manifest 085. [PLAN](../completed/PLAN-enonic-xp-deployment.md) |
| 6 | [OpenMetadata deployment](../completed/INVESTIGATE-openmetadata-deployment.md) | 2026-03-10 | Data governance v1.12.1, manifest 340. [PLAN](../completed/PLAN-openmetadata-deployment.md) |
| 7 | [Nextcloud + OnlyOffice](../completed/INVESTIGATE-nextcloud-deployment.md) | 2026-03-11 | Collaboration platform, manifest 620. [PLAN](../completed/PLAN-nextcloud-deployment.md) |
| — | [Backstage metadata & generator](../completed/PLAN-001-backstage-metadata-and-generator.md) | 2026-03-11 | Service metadata fields and catalog generator. |
| — | [Backstage deployment](../completed/PLAN-002-backstage-deployment.md) | 2026-03-12 | Deploy RHDH 1.9 with K8s plugin and catalog. |
| — | [Backstage API entities](../completed/PLAN-004-backstage-api-entities.md) | 2026-03-13 | 7 API entities with providesApis/consumesApis relationships. |
| 13 | [Container pull command](INVESTIGATE-container-pull-command.md) | 2026-03-12 | Added `./uis pull` to PowerShell wrapper. |
| — | [Documentation rewrite](../completed/PLAN-014-documentation-rewrite.md) | 2026-02-27 | Complete docs restructure. |
| — | [Documentation generation](../completed/PLAN-015-documentation-generation.md) | 2026-03-02 | Automated docs from service metadata. |
| — | [Dev template ingress cleanup](../completed/PLAN-dev-template-ingress-cleanup.md) | 2026-03-04 | Remove old ingress templates. |
| — | [PowerShell ErrorActionPreference](../completed/PLAN-uis-ps1-erroractionpreference.md) | 2026-03-04 | Fix error handling in PS wrapper. |
| — | [Backstage investigation](INVESTIGATE-backstage.md) | 2026-03-11 | Initial investigation — led to PLAN-001/002/004. |

---

## Service Migration (Historical)

The original service migration is tracked in [STATUS-service-migration.md](../completed/STATUS-service-migration.md). Summary: 25 of 26 services verified, only Gravitee remains (broken before migration — see [#3 Gravitee fix](INVESTIGATE-gravitee-fix.md)). Automated test suite (`./uis test-all`) covers 23 services with 47/47 PASS.
