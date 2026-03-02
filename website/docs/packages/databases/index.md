---
title: Databases
sidebar_label: Databases
---

# Databases

UIS provides multiple database options for different data models and use cases. PostgreSQL is the primary database used by other UIS services. The others are available for user workloads.

## Services

| Service | Type | Used by UIS | Deploy |
|---------|------|-------------|--------|
| [PostgreSQL](./postgresql.md) | Relational (SQL) | authentik, openwebui, litellm, unity-catalog, pgadmin | `./uis deploy postgresql` |
| [Redis](./redis.md) | In-memory key-value | authentik, redisinsight | `./uis deploy redis` |
| [MySQL](./mysql.md) | Relational (SQL) | — | `./uis deploy mysql` |
| [MongoDB](./mongodb.md) | Document (NoSQL) | — | `./uis deploy mongodb` |
| [Qdrant](./qdrant.md) | Vector search | — | `./uis deploy qdrant` |
| [Elasticsearch](./elasticsearch.md) | Search & analytics | — | `./uis deploy elasticsearch` |

## Quick Start

PostgreSQL and Redis are the most commonly needed databases:

```bash
./uis deploy postgresql
./uis deploy redis
```

Other databases are deployed on demand when specific applications need them.

## Custom PostgreSQL Container

UIS uses a custom PostgreSQL container (`ghcr.io/terchris/urbalurba-postgresql`) with 8 pre-built extensions including pgvector (AI embeddings), PostGIS (geospatial), and more. See [PostgreSQL container details](./postgresql-container.md).
