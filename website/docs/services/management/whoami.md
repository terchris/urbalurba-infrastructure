---
title: Whoami
sidebar_label: Whoami
---

# Whoami

Lightweight test container that returns HTTP request information, useful for debugging ingress and authentication.

| | |
|---|---|
| **Category** | Management |
| **Deploy** | `./uis deploy whoami` |
| **Undeploy** | `./uis undeploy whoami` |
| **Depends on** | None |
| **Required by** | None |
| **Image** | `traefik/whoami:v1.10.2` |
| **Default namespace** | `default` |

## What It Does

Whoami is a tiny Go web server that prints OS information and HTTP request details including headers, hostname, IP addresses, and request method. It is the first service deployed in UIS and serves two purposes:

1. **Ingress verification** — confirms that Traefik routing works correctly by responding at `http://whoami.localhost`
2. **Authentication testing** — used as the test target for Authentik forward-auth middleware, with both public and protected endpoints

## Deploy

```bash
./uis deploy whoami
```

No dependencies required. Whoami is typically the first service deployed after the cluster is ready.

## Verify

```bash
# Quick check
./uis verify whoami

# Manual check
kubectl get pods -n default -l app=whoami

# Test the endpoint
curl http://whoami.localhost
```

The response shows request headers, hostname, and IP — confirming both the pod and ingress are working.

## Configuration

Whoami has no configurable settings. It runs with default values and no secrets.

The IngressRoute is defined in the deployment playbook and creates a route for `whoami.localhost`.

## Undeploy

```bash
./uis undeploy whoami
```

## Troubleshooting

**Pod not starting:**
```bash
kubectl describe pod -n default -l app=whoami
```

**`curl http://whoami.localhost` returns nothing:**
Check that Traefik is running and the IngressRoute exists:
```bash
kubectl get ingressroute -A | grep whoami
```

**Getting nginx "Hello World" instead of whoami response:**
The IngressRoute priority may be wrong. Whoami's route must have higher priority than the nginx catch-all (priority 1).

## Learn More

- [Official repository](https://github.com/traefik/whoami)
- [Nginx catch-all service](./nginx.md)
