---
title: Completed
sidebar_position: 1
---

# Completed Plans

All completed plans and investigations, grouped by area. Kept for reference.

## Backstage

| Plan | Goal | Completed |
|------|------|-----------|
| [PLAN-004-backstage-api-entities](PLAN-004-backstage-api-entities.md) | Add API entities with provided/consumed relationships | 2026-03-13 |
| [PLAN-002-backstage-deployment](PLAN-002-backstage-deployment.md) | Deploy RHDH 1.9 with K8s plugin and catalog | 2026-03-12 |
| [PLAN-001-backstage-metadata-and-generator](PLAN-001-backstage-metadata-and-generator.md) | Add metadata to service definitions and build catalog generator | 2026-03-12 |

## Service Deployments

| Plan | Goal | Completed |
|------|------|-----------|
| [PLAN-nextcloud-deployment](PLAN-nextcloud-deployment.md) | Deploy Nextcloud 33 with OnlyOffice | 2026-03-10 |
| [PLAN-enonic-xp-deployment](PLAN-enonic-xp-deployment.md) | Deploy Enonic XP 7.16.2 CMS | 2026-03-10 |
| [PLAN-openmetadata-deployment](PLAN-openmetadata-deployment.md) | Deploy OpenMetadata 1.12.1 | 2026-03-10 |
| [PLAN-elasticsearch-upgrade](PLAN-elasticsearch-upgrade.md) | Upgrade Elasticsearch to 9.3.0 | 2026-03-09 |
| [INVESTIGATE-openmetadata-deployment](INVESTIGATE-openmetadata-deployment.md) | Investigation: OpenMetadata deployment approach | 2026-03-10 |
| [INVESTIGATE-nextcloud-deployment](INVESTIGATE-nextcloud-deployment.md) | Investigation: Nextcloud deployment approach | 2026-03-10 |
| [INVESTIGATE-elasticsearch-upgrade](INVESTIGATE-elasticsearch-upgrade.md) | Investigation: Elasticsearch upgrade and version pinning | 2026-03-09 |
| [INVESTIGATE-enonic-xp-deployment](INVESTIGATE-enonic-xp-deployment.md) | Investigation: Enonic XP CMS deployment approach | 2026-03-10 |
| [INVESTIGATE-unity-catalog-crashloop](INVESTIGATE-unity-catalog-crashloop.md) | Investigation: Unity Catalog CrashLoopBackOff | 2026-02-20 |

## Networking & Tunnels

| Plan | Goal | Completed |
|------|------|-----------|
| [PLAN-012-cloudflare-tunnel-token-deploy](PLAN-012-cloudflare-tunnel-token-deploy.md) | Token-based Cloudflare tunnel deployment | 2026-02-24 |
| [PLAN-cloudflare-tunnel-undeploy](PLAN-cloudflare-tunnel-undeploy.md) | Cloudflare tunnel fixes and undeploy playbook | 2026-02-26 |
| [PLAN-011-tailscale-cli-expose-commands](PLAN-011-tailscale-cli-expose-commands.md) | Tailscale CLI commands (expose/unexpose/verify) | 2026-02-23 |
| [PLAN-009-tailscale-service-fix](PLAN-009-tailscale-service-fix.md) | Fix Tailscale service deploy/undeploy | 2026-02-23 |
| [PLAN-tailscale-variable-rename](PLAN-tailscale-variable-rename.md) | Rename Tailscale hostname variables for clarity | 2026-02-26 |
| [INVESTIGATE-cloudflare-tunnel-uis-integration](INVESTIGATE-cloudflare-tunnel-uis-integration.md) | Investigation: Cloudflare tunnel UIS integration | 2026-02-24 |
| [INVESTIGATE-tailscale-cluster-tunnel-timeout](INVESTIGATE-tailscale-cluster-tunnel-timeout.md) | Investigation: Tailscale tunnel connectivity timeout | 2026-02-23 |
| [INVESTIGATE-tailscale-api-device-cleanup](INVESTIGATE-tailscale-api-device-cleanup.md) | Investigation: Tailscale API device cleanup | 2026-02-23 |
| [INVESTIGATE-tailscale-variable-rename](INVESTIGATE-tailscale-variable-rename.md) | Investigation: Tailscale variable rename | 2026-02-26 |
| [INVESTIGATE-network-services-remove-playbooks](INVESTIGATE-network-services-remove-playbooks.md) | Investigation: Network services remove playbooks | 2026-02-26 |

## UIS CLI & Orchestration

| Plan | Goal | Completed |
|------|------|-----------|
| [PLAN-004-uis-orchestration-system](PLAN-004-uis-orchestration-system.md) | UIS orchestration system with config-driven deployment | 2026-01-22 |
| [PLAN-004A-core-cli](PLAN-004A-core-cli.md) | UIS core CLI foundation libraries | 2026-01-22 |
| [PLAN-004B-menu-secrets](PLAN-004B-menu-secrets.md) | Interactive menu and secrets management | 2026-01-22 |
| [PLAN-004C-distribution](PLAN-004C-distribution.md) | Distribution and cross-platform support | 2026-01-22 |
| [PLAN-004D-website-testing](PLAN-004D-website-testing.md) | Website JSON generation and testing | 2026-01-22 |
| [PLAN-004E-json-schema-validation](PLAN-004E-json-schema-validation.md) | JSON schema validation framework | 2025-01-22 |
| [PLAN-004F-build-and-test](PLAN-004F-build-and-test.md) | Build and test UIS system end-to-end | 2025-01-22 |
| [PLAN-003-minimal-container-delivery](PLAN-003-minimal-container-delivery.md) | Minimal container delivery proof of concept | 2026-01-22 |
| [PLAN-002-uis-cli-commands](PLAN-002-uis-cli-commands.md) | UIS CLI commands for secrets management | 2026-01-23 |
| [PLAN-013-test-all-integration](PLAN-013-test-all-integration.md) | `./uis test-all` full integration test command | 2026-02-26 |
| [PLAN-002-json-generator](PLAN-002-json-generator.md) | Generate JSON data from script metadata | 2026-02-18 |
| [INVESTIGATE-uis-distribution](INVESTIGATE-uis-distribution.md) | Investigation: UIS distribution architecture | 2026-02-18 |
| [INVESTIGATE-old-deployment-system](INVESTIGATE-old-deployment-system.md) | Investigation: Old deployment system and UIS migration | 2026-02-18 |
| [PLAN-uis-ps1-erroractionpreference](PLAN-uis-ps1-erroractionpreference.md) | Fix uis.ps1 failure on Windows | 2026-03-04 |
| [INVESTIGATE-uis-ps1-erroractionpreference](INVESTIGATE-uis-ps1-erroractionpreference.md) | Investigation: uis.ps1 PowerShell error handling | 2026-03-04 |

## Secrets Management

| Plan | Goal | Completed |
|------|------|-----------|
| [PLAN-001-secrets-folder-structure](PLAN-001-secrets-folder-structure.md) | Secrets templates and initialization code | 2025-01-23 |
| [PLAN-003-script-migration](PLAN-003-script-migration.md) | Migrate scripts to new secrets paths | 2026-01-23 |
| [PLAN-004-secrets-cleanup](PLAN-004-secrets-cleanup.md) | Secrets migration cleanup and finalization | 2026-02-22 |
| [PLAN-fix-password-architecture](PLAN-fix-password-architecture.md) | Fix password architecture — connect orphaned defaults to templates | 2026-02-27 |
| [PLAN-007-authentik-auto-secrets](PLAN-007-authentik-auto-secrets.md) | Authentik automatic secrets application | 2026-01-31 |
| [INVESTIGATE-secrets-consolidation](INVESTIGATE-secrets-consolidation.md) | Investigation: Secrets management consolidation | 2026-02-19 |
| [INVESTIGATE-passwords](INVESTIGATE-passwords.md) | Investigation: Password architecture | 2026-02-27 |
| [INVESTIGATE-topsecret-cleanup](INVESTIGATE-topsecret-cleanup.md) | Investigation: Remove all topsecret/ references | 2026-02-22 |
| [INVESTIGATE-authentik-auto-deployment](INVESTIGATE-authentik-auto-deployment.md) | Investigation: Authentik automatic deployment | 2026-01-31 |

## Documentation

| Plan | Goal | Completed |
|------|------|-----------|
| [PLAN-015-documentation-generation](PLAN-015-documentation-generation.md) | Auto-generate service documentation from script metadata | 2026-03-02 |
| [PLAN-014-documentation-rewrite](PLAN-014-documentation-rewrite.md) | Documentation rewrite with consistent templates | 2026-02-27 |
| [PLAN-documentation-outline](PLAN-documentation-outline.md) | Add "Developing and Deploying" section | 2026-03-04 |
| [PLAN-001-branding-setup](PLAN-001-branding-setup.md) | Set up UIS branding | 2026-01-19 |
| [INVESTIGATE-documentation-generation](INVESTIGATE-documentation-generation.md) | Investigation: Auto-generated docs from metadata | 2026-02-27 |
| [INVESTIGATE-documentation-rewrite](INVESTIGATE-documentation-rewrite.md) | Investigation: Documentation rewrite prototype | 2026-02-27 |
| [INVESTIGATE-documentation-outline](INVESTIGATE-documentation-outline.md) | Investigation: Documentation site restructure | 2026-03-04 |
| [INVESTIGATE-docs-restructure](INVESTIGATE-docs-restructure.md) | Investigation: Documentation restructuring for Docusaurus | 2026-02-18 |

## ArgoCD

| Plan | Goal | Completed |
|------|------|-----------|
| [PLAN-argocd-register-redesign](PLAN-argocd-register-redesign.md) | ArgoCD register command redesign | 2026-03-03 |
| [PLAN-argocd-migration](PLAN-argocd-migration.md) | ArgoCD migration completion | 2026-02-18 |
| [INVESTIGATE-argocd-migration](INVESTIGATE-argocd-migration.md) | Investigation: ArgoCD migration and cleanup | 2026-02-18 |
| [INVESTIGATE-argocd-register-url-parsing](INVESTIGATE-argocd-register-url-parsing.md) | Investigation: ArgoCD register command redesign | 2026-03-03 |

## Other

| Plan | Goal | Completed |
|------|------|-----------|
| [STATUS-service-migration](STATUS-service-migration.md) | Service migration status and remaining work | 2026-02-27 |
| [PLAN-dev-template-ingress-cleanup](PLAN-dev-template-ingress-cleanup.md) | Dev template ingress cleanup | 2026-03-04 |
| [PLAN-005-kubeconfig-path-migration](PLAN-005-kubeconfig-path-migration.md) | Migrate playbooks to new kubeconfig path | 2026-02-19 |
| [INVESTIGATE-adding-new-service](INVESTIGATE-adding-new-service.md) | How to add a new service to UIS | 2026-03-05 |
| [INVESTIGATE-dev-template-ingress-cleanup](INVESTIGATE-dev-template-ingress-cleanup.md) | Investigation: Dev template IngressRoute cleanup | 2026-03-03 |
| [INVESTIGATE-rancher-reset-and-full-verification](INVESTIGATE-rancher-reset-and-full-verification.md) | Investigation: Rancher reset and full verification | 2026-02-20 |
| [INVESTIGATE-whoami-kubeconfig-path](INVESTIGATE-whoami-kubeconfig-path.md) | Investigation: Playbooks using old kubeconfig path | 2026-02-19 |
