# Platform Roadmap

> **IMPLEMENTATION RULES:** Before implementing this plan, read and follow:
> - [WORKFLOW.md](../../WORKFLOW.md) - The implementation process
> - [PLANS.md](../../PLANS.md) - Plan structure and best practices

## Status: Active

**Goal**: Track prioritized investigations and planned work for the UIS platform

**Last Updated**: 2026-03-10

---

## Priority 1: Infrastructure Hardening

These items reduce risk, fix broken services, and unblock new service deployments.

| # | Investigation | Status | Blocks | Summary |
|---|--------------|--------|--------|---------|
| 1 | [Elasticsearch upgrade](../completed/INVESTIGATE-elasticsearch-upgrade.md) | Complete | OpenMetadata | Upgrade ES 8.5.1 → 9.3.0. Pinned `imageTag: "9.3.0"`. Verified by tester. |
| 2 | [Version pinning](INVESTIGATE-version-pinning.md) | Backlog | — | 18 of 21 Helm charts unpinned. Should happen alongside ES upgrade. |
| 2b | [Service version metadata](INVESTIGATE-service-version-metadata.md) | Backlog | — | Decide how service scripts expose version info for docs generation. Docs generator hardcodes "(unpinned)" even for pinned services. |
| 3 | [Gravitee fix](INVESTIGATE-gravitee-fix.md) | Backlog | — | Only unverified service. Hardcoded credentials, no remove playbook, wrong namespace, `Host()` instead of `HostRegexp()`. |

---

## Priority 2: New Service Deployments

New platform services. Enonic and OpenMetadata have dependencies on Priority 1 items.

| # | Investigation | Status | Depends on | Summary |
|---|--------------|--------|------------|---------|
| 4 | [Enonic XP deployment](../completed/INVESTIGATE-enonic-xp-deployment.md) | Complete | — | CMS platform. Plain Docker/StatefulSet, manifest 085. Reuses cluster storage. Deployed and verified (6 E2E tests pass). |
| 5 | [Enonic app deployment pipeline](INVESTIGATE-enonic-app-deployment-pipeline.md) | Investigation complete | Enonic XP (#4) | Sidecar pulls JARs from GitHub Releases into `$XP_HOME/deploy`. UIS CLI commands. |
| 6 | [OpenMetadata deployment](../completed/INVESTIGATE-openmetadata-deployment.md) | Complete | ES upgrade (#1) ✅ | Data governance platform v1.12.1, manifest 340. Reuses PostgreSQL + Elasticsearch 9.3.0. K8s native orchestrator (no Airflow). Deployed and verified (6 E2E tests pass). |
| 7 | [Nextcloud + OnlyOffice](../completed/INVESTIGATE-nextcloud-deployment.md) | Complete | — | Collaboration platform, manifest 620. Reuses PostgreSQL + Redis. OnlyOffice for document editing. Deployed and verified (8 E2E tests pass). |
| 8 | [Enonic content deployment](INVESTIGATE-enonic-content-deployment.md) | Backlog | Enonic XP (#4) | Content migration between environments. Manual workflow works initially — automate later. |

---

## Priority 3: Platform Improvements

Feature improvements that are not blocking anything.

| # | Investigation | Status | Summary |
|---|--------------|--------|---------|
| 9 | [Authentik user config](INVESTIGATE-authentik-user-config.md) | Investigation complete | Move user-configurable Authentik data from `manifests/` to `.uis.extend/`. |
| 12 | [Docs markdown update logic](INVESTIGATE-docs-markdown-update-logic.md) | Backlog | `uis-docs-markdown.sh` can only skip or overwrite pages — no merge/update mode. Metadata changes in service scripts are never reflected in existing docs pages. |

---

## Priority 4: Future Work

Requires real infrastructure or has no immediate need.

| # | Investigation | Status | Summary |
|---|--------------|--------|---------|
| 10 | [Host docs migration](INVESTIGATE-host-docs-migration.md) | Backlog | Legacy host docs still describe old deployment approach. Blocked by remote targets. |
| 11 | [Remote deployment targets](INVESTIGATE-remote-deployment-targets.md) | Investigation complete | Azure AKS, Multipass, Raspberry Pi. Needs real infrastructure to test. |

---

## Completed Investigations

Investigations where the work has been implemented. The INVESTIGATE files have been moved to `../completed/`.

| Investigation | Completed | Plan |
|--------------|-----------|------|
| Documentation rewrite | 2026-02-27 | [PLAN-014](../completed/PLAN-014-documentation-rewrite.md) |
| Documentation generation | 2026-03-02 | [PLAN-015](../completed/PLAN-015-documentation-generation.md) |
| Dev template ingress cleanup | 2026-03-04 | [PLAN-dev-template-ingress-cleanup](../completed/PLAN-dev-template-ingress-cleanup.md) |
| PowerShell ErrorActionPreference | 2026-03-04 | [PLAN-uis-ps1-erroractionpreference](../completed/PLAN-uis-ps1-erroractionpreference.md) |
| Elasticsearch upgrade | 2026-03-09 | [PLAN-elasticsearch-upgrade](../completed/PLAN-elasticsearch-upgrade.md) |
| OpenMetadata deployment | 2026-03-10 | [PLAN-openmetadata-deployment](../completed/PLAN-openmetadata-deployment.md) |
| Enonic XP deployment | 2026-03-10 | [PLAN-enonic-xp-deployment](../completed/PLAN-enonic-xp-deployment.md) |
| Nextcloud + OnlyOffice deployment | 2026-03-11 | [PLAN-nextcloud-deployment](../completed/PLAN-nextcloud-deployment.md) |

---

## Service Migration (Historical)

The original service migration is tracked in [STATUS-service-migration.md](../completed/STATUS-service-migration.md). Summary: 25 of 26 services verified, only Gravitee remains (broken before migration — see [#3 Gravitee fix](INVESTIGATE-gravitee-fix.md)). Automated test suite (`./uis test-all`) covers 23 services with 47/47 PASS.
