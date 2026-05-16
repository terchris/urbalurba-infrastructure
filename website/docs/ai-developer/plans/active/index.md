---
title: Active Plans
sidebar_position: 1
---

# Active Plans

Plans currently being implemented. Maximum 1-2 at a time.

| Plan | Goal | Updated |
|------|------|---------|
| [Plan: derive `TAILSCALE_OWNER_ID` default from `GITHUB_USERNAME` + soft-warn validation guards](PLAN-network-tailscale-owner-id-default.md) | Close the contributor-bypass gap left after PLAN-002 — a fresh install that skips the wizard and runs `./uis secrets generate` directly should still produce a non-colliding `TAILSCALE_OWNER_ID`. Soft-warn (matching the existing `DEFAULT_*` placeholder pattern) when the resolved value is missing or malformed. | 2026-05-16 |
