---
title: RabbitMQ
sidebar_label: RabbitMQ
---

# RabbitMQ

Message broker for asynchronous communication between services.

| | |
|---|---|
| **Category** | Integration |
| **Deploy** | `./uis deploy rabbitmq` |
| **Undeploy** | `./uis undeploy rabbitmq` |
| **Depends on** | None |
| **Required by** | None |
| **Helm chart** | `bitnami/rabbitmq` (unpinned) |
| **Default namespace** | `default` |

## What It Does

RabbitMQ provides message queuing and pub/sub messaging for decoupling services. Applications publish messages to exchanges, which route them to queues for consumption by other services.

Key capabilities:
- **Message queuing** — reliable delivery with acknowledgments and persistence
- **Pub/sub** — publish messages to multiple consumers via topic exchanges
- **Management UI** — web-based dashboard on port 15672
- **AMQP protocol** — standard messaging protocol on port 5672
- **8Gi persistent storage** — messages survive pod restarts

## Deploy

```bash
./uis deploy rabbitmq
```

No dependencies.

## Verify

```bash
# Quick check
./uis verify rabbitmq

# Manual check
kubectl get pods -n default -l app.kubernetes.io/name=rabbitmq

# Test management UI
curl -s -o /dev/null -w "%{http_code}" http://rabbitmq.localhost
# Expected: 200
```

Access the management UI at [http://rabbitmq.localhost](http://rabbitmq.localhost).

## Configuration

| Setting | Value | Notes |
|---------|-------|-------|
| AMQP port | `5672` | Message protocol |
| Management port | `15672` | Web UI |
| Architecture | `standalone` | Single instance |
| Storage | `8Gi` PVC | Persistent messages |

### Secrets

| Variable | File | Purpose |
|----------|------|---------|
| `DEFAULT_RABBITMQ_USERNAME` | `.uis.secrets/secrets-config/default-secrets.env` | Admin username |
| `DEFAULT_RABBITMQ_PASSWORD` | `.uis.secrets/secrets-config/default-secrets.env` | Admin password |

### Key Files

| File | Purpose |
|------|---------|
| `ansible/playbooks/080-setup-rabbitmq.yml` | Deployment playbook |
| `ansible/playbooks/080-remove-rabbitmq.yml` | Removal playbook |

## Undeploy

```bash
./uis undeploy rabbitmq
```

## Troubleshooting

**Pod won't start:**
```bash
kubectl describe pod -l app.kubernetes.io/name=rabbitmq
kubectl logs -l app.kubernetes.io/name=rabbitmq
```

**Authentication failed on management UI:**
Check credentials in secrets:
```bash
kubectl get secret urbalurba-secrets -o jsonpath="{.data.RABBITMQ_USERNAME}" | base64 -d
kubectl get secret urbalurba-secrets -o jsonpath="{.data.RABBITMQ_PASSWORD}" | base64 -d
```

**Connection refused on AMQP port:**
```bash
kubectl get svc rabbitmq
kubectl get endpoints rabbitmq
```

## Learn More

- [Official RabbitMQ documentation](https://www.rabbitmq.com/docs)
- [Bitnami RabbitMQ Helm chart](https://github.com/bitnami/charts/tree/main/bitnami/rabbitmq)
