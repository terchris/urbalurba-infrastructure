---
title: Analytics
sidebar_label: Analytics
---

# Analytics

The analytics package provides data science and analytics platforms for interactive analysis, distributed processing, and data governance.

## Services

| Service | Description | Deploy |
|---------|-------------|--------|
| [JupyterHub](./jupyterhub.md) | Multi-user Jupyter notebooks with PySpark | `./uis deploy jupyterhub` |
| [Apache Spark](./spark.md) | Kubernetes-native distributed processing | `./uis deploy spark` |
| [Unity Catalog](./unitycatalog.md) | Data catalog and governance | `./uis deploy unity-catalog` |

## Quick Start

```bash
./uis stack install analytics
```

Or deploy individually:

```bash
./uis deploy postgresql    # Required by Unity Catalog
./uis deploy spark
./uis deploy jupyterhub
./uis deploy unity-catalog
```

## How It Works

- **JupyterHub** gives users interactive notebooks with PySpark pre-configured
- **Spark Operator** runs batch jobs as Kubernetes-native SparkApplication resources
- **Unity Catalog** provides a three-level namespace (catalog.schema.table) for governed data access
