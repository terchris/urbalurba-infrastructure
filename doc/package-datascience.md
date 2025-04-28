# Datascience Package

This package contains the tools and services for datascience software. It is a local alternative to Databricks implemented using open source tools.

This is a suggestion for how we can set up a local development and testing environment that closely mimics your Databricks production environment, using lightweight and open source components. The setup will run inside a Kubernetes cluster managed by Rancher Desktop on developers' machines.

## Core Components

| Component | Purpose |
|-----------|---------|
| [JupyterHub](https://jupyter.org/hub) | Provides a familiar notebook interface for SQL, Python, and data visualization workflows, similar to Databricks notebooks. |
| [DuckDB](https://duckdb.org) | Embedded SQL engine inside Jupyter for querying local Parquet files with complex SQL support. Fast and lightweight for small- to medium-sized data workloads. |
| [Trino](https://trino.io) | Distributed SQL query engine that can query multiple systems (Postgres, MongoDB, Redis, Elasticsearch, Parquet files, and more) via a unified SQL interface. Bridges the gap between different local data sources. |
| Parquet Storage | Developers export data from Databricks as Parquet files. Files are mounted inside Kubernetes using hostPath volumes, allowing direct access from notebooks without copying into containers. |
| Azure API Management (APIM) / Apigee Gateway | API gateway that transforms incoming requests into SQL queries (in production via APIM, in development via Apigee). Allows interaction with data via standardized APIs. |

### Developer Workflow

1. **Data Export and Access**:
   - Developers export Parquet files from Databricks production
   - Files are placed directly on the developer machine
   - Accessible to the local Kubernetes cluster via mounted volumes

2. **Development Environment**:
   - Inside Jupyter notebooks, developers can:
     - Query Parquet files using DuckDB
     - Query Postgres, MongoDB, Redis, Elasticsearch, and Qdrant using Trino — all with standard SQL
     - Test API integrations through the local Apigee gateway
   - SQL queries and workflows match Databricks, minimizing learning curve

### Installation Plan

1. **Kubernetes Cluster Setup**:
   - Use Rancher Desktop to run a local K8s cluster
   - Configure persistent storage mapped to host machine disk

2. **JupyterHub Deployment**:
   - Install via official Helm chart
   - Extend image to include DuckDB extensions

3. **Trino Setup**:
   - Deploy using official Helm chart
   - Configure connectors for:
     - Postgres
     - MongoDB
     - Redis
     - Elasticsearch
     - Qdrant
     - Parquet file access

4. **API Gateway Configuration**:
   - Deploy Apigee locally inside cluster
   - Set up policies mapping API calls to SQL queries
   - Mimic APIM production setup

5. **Storage Configuration**:
   - Use Kubernetes persistent volumes based on hostPath
   - Enable direct Parquet file access from local disk

### Advantages

- **Fully open source and lightweight**: Easy to run on a developer laptop
- **Familiar workflows**: SQL notebooks matching Databricks experience
- **Unified query engine**: Trino enables cross-database joins and queries
- **Flexible data access**: Query multiple data sources through SQL
- **Simple integration testing**: Local API layer without Databricks/Azure dependency

### API Query Implementation

In production:
- APIM policies format requests into SQL queries for Databricks' SQL API
- Sets method to POST
- Formats SQL statement body
- Attaches authentication headers
- Rewrites path to SQL execution endpoint

In local development:
- Apigee performs same transformations
- Builds POST requests with SQL statements
- Sends to Trino (or DuckDB for Parquet-only queries)
- Enables local API behavior testing without Databricks connection

### Summary

This local development environment provides a Databricks-like experience using open source tools in a lightweight Kubernetes cluster. Developers can:
- Work with SQL queries across multiple data sources
- Use familiar notebook interfaces
- Test API integrations locally
- Maintain production-like workflows without cloud dependencies

