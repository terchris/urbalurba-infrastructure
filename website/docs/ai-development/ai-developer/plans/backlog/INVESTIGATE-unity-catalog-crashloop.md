# INVESTIGATE: Unity Catalog CrashLoopBackOff

**Related**: [INVESTIGATE-rancher-reset-and-full-verification](INVESTIGATE-rancher-reset-and-full-verification.md)
**Created**: 2026-02-20

## Problem

Unity Catalog server pod enters `CrashLoopBackOff` / `RunContainerError` after deployment via `./uis deploy unity-catalog`.

- PostgreSQL dependency was deployed and healthy
- The Ansible playbook runs without errors
- The pod fails to start (never becomes ready, times out after 180s)
- Undeploy works correctly

## Context

Discovered during full service verification (talk9.md, Round 6, Step 9). All other 20 testable services deploy and undeploy successfully from a clean slate after factory reset.

## Investigation Steps

1. Check pod logs: `kubectl logs -n unity-catalog <pod-name>`
2. Check pod events: `kubectl describe pod -n unity-catalog <pod-name>`
3. Check if the Unity Catalog container image can be pulled
4. Check if the PostgreSQL connection details are correct
5. Review the deployment playbook: `ansible/playbooks/320-setup-unity-catalog.yml`
6. Review the service definition: `provision-host/uis/services/datascience/service-unity-catalog.sh`

## Possible Causes

- Container image issue (wrong tag, architecture mismatch)
- PostgreSQL connection configuration mismatch
- Missing environment variables or secrets
- Resource constraints (memory/CPU limits too low)
