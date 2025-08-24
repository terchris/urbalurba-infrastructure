# Elasticsearch Version Deployment Guide

## Overview

This guide explains how to deploy Elasticsearch with a specific version (8.16.x) using the updated Ansible playbook and shell script.

## Current Implementation

The Elasticsearch setup has been updated to support version specification with the following changes:

### Ansible Playbook (`060-setup-elasticsearch.yml`)

- **Version Parameter**: Added `elasticsearch_version` variable with default value `8.16.1`
- **Version Validation**: Ensures only 8.16.x versions are accepted
- **Helm Integration**: Uses `--set image.tag={{ elasticsearch_version }}` in Helm install command
- **Single-Node Configuration**: Optimized for fast startup with minimal resource usage

### Shell Script (`07-setup-elasticsearch.sh`)

- **Simplified**: Always uses default version 8.16.1
- **No Parameters**: Only requires target host specification

## Usage Options

### Option 1: Use Default Version (8.16.1)

**Via Shell Script:**
```bash
./07-setup-elasticsearch.sh multipass-microk8s
```

**Via Ansible Playbook:**
```bash
ansible-playbook playbooks/060-setup-elasticsearch.yml -e target_host="multipass-microk8s"
```

### Option 2: Specify Custom 8.16.x Version

**Via Ansible Playbook Only:**
```bash
ansible-playbook playbooks/060-setup-elasticsearch.yml \
  -e target_host="multipass-microk8s" \
  -e elasticsearch_version="8.16.1"
```

## Downgrading Existing Installations

To downgrade an existing Elasticsearch installation:

1. **Uninstall current version:**
   ```bash
   helm uninstall elasticsearch --namespace elasticsearch
   ```

2. **Reinstall with desired version:**
   ```bash
       # Using shell script (default 8.16.1)
    ./07-setup-elasticsearch.sh multipass-microk8s
    
    # Or using Ansible with specific version
    ansible-playbook playbooks/060-setup-elasticsearch.yml \
      -e target_host="multipass-microk8s" \
      -e elasticsearch_version="8.16.1"
   ```

## Version Compatibility

- **Supported Versions**: Only Elasticsearch 8.16.x versions
- **Format**: Must follow X.Y.Z pattern (e.g., 8.16.3, 8.16.2, 8.16.1)
- **Validation**: Playbook automatically validates version format and range

## Configuration

The setup uses the existing `manifests/060-elasticsearch-config.yaml` configuration file, which is compatible with Elasticsearch 8.16.x.

## Benefits

- **Version Flexibility**: Can specify any 8.16.x version via Ansible parameter
- **Default Behavior**: Script always uses 8.16.1 unless overridden
- **Simple Downgrade**: Just uninstall and reinstall with new version
- **No Duplicate Configs**: Maintains single source of truth for configuration
- **Validation**: Ensures only compatible versions are deployed
