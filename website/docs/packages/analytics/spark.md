---
title: Apache Spark
sidebar_label: Spark
---

# Apache Spark

Kubernetes-native distributed data processing engine.

| | |
|---|---|
| **Category** | Analytics |
| **Deploy** | `./uis deploy spark` |
| **Undeploy** | `./uis undeploy spark` |
| **Depends on** | None |
| **Required by** | None |
| **Helm chart** | `spark-operator/spark-operator` (unpinned) |
| **Default namespace** | `spark-operator` |

## What It Does

The Spark Kubernetes Operator enables running Apache Spark jobs natively on Kubernetes using SparkApplication custom resources. Instead of managing a standalone Spark cluster, you submit jobs as Kubernetes manifests.

Key capabilities:
- **SparkApplication CRD** — declarative job definitions as YAML
- **ARM64 support** — runs on Apple Silicon and ARM-based clusters
- **Multi-language** — PySpark, Scala, Java, R
- **Resource management** — Kubernetes-native CPU/memory requests and limits
- **Job scheduling** — cron-based scheduling via ScheduledSparkApplication
- **100% Databricks compatible** — same Spark runtime

## Deploy

```bash
./uis deploy spark
```

No dependencies.

## Verify

```bash
# Quick check
./uis verify spark

# Manual check
kubectl get pods -n spark-operator

# Check the CRD is installed
kubectl get crd sparkapplications.sparkoperator.k8s.io
```

## Configuration

The Spark operator manages jobs via SparkApplication CRDs. No additional config files are needed for the operator itself.

### Key Files

| File | Purpose |
|------|---------|
| `ansible/playbooks/330-setup-spark.yml` | Deployment playbook |
| `ansible/playbooks/330-remove-spark.yml` | Removal playbook |

## Undeploy

```bash
./uis undeploy spark
```

Running Spark jobs will be terminated.

## Troubleshooting

**Operator pod won't start:**
```bash
kubectl describe pod -n spark-operator -l app.kubernetes.io/name=spark-operator
kubectl logs -n spark-operator -l app.kubernetes.io/name=spark-operator
```

**SparkApplication stuck in PENDING:**
Check driver pod events:
```bash
kubectl describe sparkapplication -n spark-operator <app-name>
kubectl describe pod -n spark-operator <driver-pod>
```

**Executor pods not launching:**
Verify resource quotas and available capacity:
```bash
kubectl top nodes
```

## Learn More

- [Official Apache Spark documentation](https://spark.apache.org/docs/latest/)
- [Spark Operator GitHub](https://github.com/kubeflow/spark-operator)
- [JupyterHub PySpark integration](./jupyterhub.md)
