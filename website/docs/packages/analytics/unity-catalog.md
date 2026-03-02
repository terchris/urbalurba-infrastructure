---
title: Unity Catalog
sidebar_label: Unity Catalog
---

# Unity Catalog

Open-source data catalog and governance

| | |
|---|---|
| **Category** | Analytics |
| **Deploy** | `./uis deploy unity-catalog` |
| **Undeploy** | `./uis undeploy unity-catalog` |
| **Depends on** | postgresql |
| **Required by** | None |
| **Image** | `unitycatalog/unitycatalog:latest` |
| **Default namespace** | `unity-catalog` |

## What It Does

Unity Catalog is an open-source data catalog that provides unified governance for data and AI assets. It enables fine-grained access control, data lineage tracking, and metadata management across your data lakehouse.

## Deploy

```bash
# Prerequisites — deploy dependencies first
./uis deploy postgresql

# Deploy Unity Catalog
./uis deploy unity-catalog
```

## Verify

```bash
# Quick check
./uis verify unity-catalog

# Manual check
kubectl get pods -n unity-catalog -l app=unity-catalog,component=server
```

## Configuration

<!-- MANUAL: Service-specific configuration details -->
_No configuration documentation yet. Edit this section to add details about Unity Catalog settings, secrets, and customization options._

## Undeploy

```bash
./uis undeploy unity-catalog
```

## Troubleshooting

<!-- MANUAL: Common issues and solutions -->
_No troubleshooting documentation yet. Edit this section to add common issues and their solutions._

## Learn More

- [Official Unity Catalog documentation](https://www.unitycatalog.io)
