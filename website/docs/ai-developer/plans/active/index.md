---
title: Active Plans
sidebar_position: 1
---

# Active Plans

Plans currently being implemented. Maximum 1-2 at a time.

| Plan | Goal | Updated |
|------|------|---------|
| [PLAN: per-instance rows in `./uis status` + `./uis list` for multi-instance services](PLAN-cli-status-multi-instance.md) | Make multi-instance service deployments individually visible in `./uis status` and `./uis list`. After this PLAN ships, deploying `postgrest --app atlas` + `postgrest --app railway` produces two rows in the status table (`atlas-postgrest`, `railway-postgrest`) instead of a single binary `postgrest ✅ Healthy` row, so the user can identify each instance by its Kubernetes Service name — the same string they need for `./uis network expose tailscale <name>`. | 2026-05-16 |
