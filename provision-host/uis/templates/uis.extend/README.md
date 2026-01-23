# UIS Configuration Directory

This directory contains user-specific configuration for UIS.

## Files

| File | Description |
|------|-------------|
| `enabled-services.conf` | List of services to deploy |
| `enabled-tools.conf` | List of additional tools to install |
| `cluster-config.sh` | Cluster-specific configuration |
| `service-overrides/` | Custom overrides for services |

## Usage

### Enable/Disable Services

```bash
# List available services
uis list

# Enable a service
uis enable prometheus

# Disable a service
uis disable prometheus

# Show enabled services
uis list-enabled
```

### Deploy Services

```bash
# Deploy all enabled services
uis deploy

# Deploy a specific service
uis deploy grafana
```

## Service Overrides

Place custom configuration files in `service-overrides/` to override defaults.
The format is `<service-id>-config.yaml`.
