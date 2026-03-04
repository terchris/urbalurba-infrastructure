---
title: ArgoCD Dashboard
sidebar_label: ArgoCD Dashboard
sidebar_position: 5
---

# ArgoCD Dashboard

ArgoCD provides a web UI for viewing and managing your deployed applications. It shows real-time sync status, health information, and the full resource tree for each application.

## Accessing the dashboard

Open [http://argocd.localhost](http://argocd.localhost) in your browser.

No login is required — the platform configures ArgoCD with anonymous access for local development.

## Application overview

The main page shows all registered applications as cards. Each card displays:

- **Application name** — the name you used in `uis argocd register`
- **Sync status** — whether the cluster matches the Git repository
- **Health status** — whether pods are running correctly
- **Repository** — the GitHub repo URL
- **Namespace** — where the app is deployed

## Sync states

| Status | Meaning |
|--------|---------|
| **Synced** | Cluster state matches the Git repository — everything is up to date |
| **OutOfSync** | Git has changes that haven't been applied to the cluster yet |
| **Unknown** | ArgoCD can't determine the sync state |

When auto-sync is enabled (the default for apps registered with `uis argocd register`), OutOfSync states resolve automatically within a few minutes.

## Health states

| Status | Meaning |
|--------|---------|
| **Healthy** | All pods are running and passing health checks |
| **Progressing** | A deployment is in progress (rolling update) |
| **Degraded** | One or more pods are failing |
| **Missing** | Expected resources don't exist in the cluster |
| **Suspended** | Application is paused |

## Application detail view

Click an application card to see:

- **Resource tree** — visual hierarchy of all Kubernetes resources (Deployment, ReplicaSet, Pod, Service, IngressRoute)
- **Sync details** — which resources are in sync and which are not
- **Events** — recent Kubernetes events for the application's resources
- **Logs** — container logs from running pods (click a pod in the resource tree)
- **Diff** — side-by-side comparison of desired state (Git) vs live state (cluster)

## Manual operations

### Sync

Click **Sync** to manually trigger a sync from Git. Useful when you want to force an immediate update instead of waiting for auto-sync.

### Refresh

Click **Refresh** to re-read the Git repository. This detects new commits without applying them — use Sync to apply.

### Rollback

The **History** tab shows previous sync operations. You can view what changed in each sync, but rollback should be done through Git (revert the commit) rather than through the ArgoCD UI, since auto-sync would revert any manual rollback.

## Troubleshooting from the dashboard

### Pod is in CrashLoopBackOff

1. Click the application → find the red pod in the resource tree
2. Click the pod → **Logs** tab
3. The logs show why the container is crashing (e.g., missing environment variable, port conflict)

### Pod is in ImagePullBackOff

1. Click the pod → **Events** tab
2. Look for the error message — usually the image name or tag is wrong
3. Check that the GitHub Actions workflow ran and pushed the image to GHCR

### Application stuck in Progressing

1. Check if new pods are starting: look at the ReplicaSet in the resource tree
2. If pods can't start, the old pods stay running (Kubernetes won't terminate them until new ones are ready)
3. Check pod events and logs for the root cause
