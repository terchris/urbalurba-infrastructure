---
title: Active Plans
sidebar_position: 1
---

# Active Plans

Plans currently being implemented. Maximum 1-2 at a time.

| Plan | Goal | Updated |
|------|------|---------|
| [Plan: User-facing tools documentation + cleanup of contributor tools doc](PLAN-tools-docs.md) | Make the tools available inside `uis-provision-host` discoverable from the user-facing parts of the docs (today they're only in `contributors/`), and bring the existing contributor doc into line with reality (currently claims tools are pre-installed, lists `terraform`/`oci`/etc. that aren't actually in the system). | 2026-05-13 |
| [Plan: Harden `./uis tools install` scripts — fail loudly, run repeatedly](PLAN-tool-installer-error-handling.md) | Make every `provision-host/uis/tools/install-*.sh` script (a) safely re-runnable any number of times and (b) return a non-zero exit code if any installation step fails — including silent failures inside piped `curl | bash` invocations and sequential `apt-get` commands. | 2026-05-13 |
| [PLAN-002: Tailscale network CLI port](PLAN-002-tailscale-network-port-cli.md) | Port Tailscale from `uis tailscale expose/unexpose/verify` + `uis deploy tailscale-tunnel` to a first-class `uis network <verb> tailscale` family symmetric with the Cloudflare port. | 2026-05-14 |
