---
title: Active Plans
sidebar_position: 1
---

# Active Plans

Plans currently being implemented. Maximum 1-2 at a time.

| Plan | Goal | Updated |
|------|------|---------|
| [Plan: Gravitee APIM 4.11 deployment on PostgreSQL](PLAN-gravitee-postgresql-deployment.md) | After this plan, `./uis deploy postgresql && ./uis deploy gravitee` on a fresh local cluster produces a working Gravitee APIM 4.11 deployment with admin Console, Developer Portal, and API Gateway, backed by PostgreSQL — no MongoDB, no Elasticsearch, no Redis. `./uis undeploy gravitee --purge` cleanly tears down all Gravitee state. | 2026-05-05 |
| [Feature: Add `./uis pull` command](PLAN-container-pull-command.md) | Add a `./uis pull` command to the repo-root wrapper that pulls the latest container image and restarts the container | 2026-05-05 |
