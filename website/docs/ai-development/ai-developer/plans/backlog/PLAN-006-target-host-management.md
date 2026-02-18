# PLAN-006: Target/Host Management

## Status: Backlog

## Problem

Users have no easy way to:
1. See which Kubernetes cluster they're deploying to
2. Switch between different targets (rancher-desktop, azure-aks, etc.)
3. Understand the relationship between UIS hosts and kubectl context

Currently:
- Target defaults to `rancher-desktop`
- User must manually manage kubectl context
- `./uis host list` shows configured hosts but not the active target
- No synchronization between UIS and kubectl context

## Quick Fix Implemented

Added target cluster display to `./uis status`:
```
Target cluster: rancher-desktop
```

## Full Solution Required

### New Commands

1. `./uis target` - Show current target cluster
2. `./uis target list` - List available targets
3. `./uis target set <name>` - Switch to a different target

### Implementation Requirements

1. **Track active target** in `.uis.extend/active-target`
2. **Sync kubectl context** when target changes
3. **Validate target exists** before switching
4. **Show target in commands** that deploy/interact with cluster
5. **Handle multiple kubeconfigs** for different clusters

### User Flow

```bash
# See current target
./uis target
# Output: Current target: rancher-desktop

# List available targets
./uis target list
# Output:
#   rancher-desktop (active)
#   azure-aks-prod
#   raspberry-pi-cluster

# Switch target
./uis target set azure-aks-prod
# Output: Switched to azure-aks-prod
```

### Files to Modify

- `provision-host/uis/manage/uis-cli.sh` - Add target commands
- `provision-host/uis/lib/uis-hosts.sh` - Target management logic
- `uis` wrapper - Pass target commands through

### Dependencies

- Requires kubeconfig files for each target in `.uis.secrets/generated/kubeconfig/`
- Host templates should generate appropriate kubeconfig entries

## Priority

Medium - Users can work around this by manually managing kubectl context

## Created

2026-01-23 during UIS menu system testing
