---
title: Active Plans
sidebar_position: 1
---

# Active Plans

Plans currently being implemented. Maximum 1-2 at a time.

| Plan | Goal | Updated |
|------|------|---------|
| [Plan: Harden `./uis tools install` scripts — fail loudly, run repeatedly](PLAN-tool-installer-error-handling.md) | Make every `provision-host/uis/tools/install-*.sh` script (a) safely re-runnable any number of times and (b) return a non-zero exit code if any installation step fails — including silent failures inside piped `curl | bash` invocations and sequential `apt-get` commands. | 2026-05-15 |
