---
title: Active Plans
sidebar_position: 1
---

# Active Plans

Plans currently being implemented. Maximum 1-2 at a time.

| Plan | Goal | Updated |
|------|------|---------|
| [Plan: User-facing tools documentation + cleanup of contributor tools doc](PLAN-tools-docs.md) | Make the tools available inside `uis-provision-host` discoverable from the user-facing parts of the docs (today they're only in `contributors/`), and bring the existing contributor doc into line with reality (currently claims tools are pre-installed, lists `terraform`/`oci`/etc. that aren't actually in the system). | 2026-05-08 |
| [Plan: AKS Step 1 — Verify minimal working cluster end-to-end](PLAN-001-aks-step1-verification.md) | Take the unverified `platforms/aks/` OpenTofu drafts (merged 2026-04-09 via PR #120) through their first real end-to-end run against an Azure subscription, fix any gaps that surface, and earn the right to call AKS Step 1 *actually* shipped — by deploying `./uis deploy nginx` against the resulting cluster and watching its built-in connectivity tests pass. | 2026-05-08 |
