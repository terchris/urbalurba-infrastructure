---
title: Management
sidebar_label: Management
---

# Management

Admin tools, GitOps, and utility services for managing the UIS platform.

## Services

| Service | Description | Deploy |
|---------|-------------|--------|
| [ArgoCD](./argocd.md) | GitOps continuous delivery | `./uis deploy argocd` |
| [pgAdmin](./pgadmin.md) | PostgreSQL web admin | `./uis deploy pgadmin` |
| [RedisInsight](./redisinsight.md) | Redis web admin | `./uis deploy redisinsight` |
| [Nginx](./nginx.md) | Catch-all web server and default backend | `./uis deploy nginx` |
| [Whoami](./whoami.md) | HTTP request test service | `./uis deploy whoami` |

## Overview

- **ArgoCD** automates deployments from Git repositories
- **pgAdmin** and **RedisInsight** provide web interfaces for their respective databases
- **Nginx** serves as the default backend — any request that doesn't match a service gets the Nginx landing page
- **Whoami** is a diagnostic tool for testing ingress and authentication
