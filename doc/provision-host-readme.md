# Provision Host Documentation

The provision host is a containerized environment that contains all necessary tools for managing the Urbalurba infrastructure. This document provides detailed information about the provision host setup and its components.

## Overview

The provision host is set up using a series of scripts that install and configure various tools and services. These scripts are designed to be run in sequence to ensure proper installation and configuration.

## Installation Scripts

### 1. Core Software Installation (`provision-host-00-coresw.sh`)

This script installs the core software tools required for the provision host:

- **GitHub CLI (gh)**
  - Used for GitHub repository management
  - Installs the latest stable version
  - Supports both x86_64 and aarch64 architectures

### 2. Cloud Provider Tools (`provision-host-01-cloudproviders.sh`)

Installs and configures tools for various cloud providers:

- **Azure CLI**
  - Command-line interface for Azure management
  - Supports containerized environments
  - Includes systemd service configuration

- **OCI CLI (Oracle Cloud)**
  - Python-based CLI for Oracle Cloud
  - Installs in a virtual environment
  - Configures PATH and shell integration

- **AWS CLI**
  - Command-line interface for AWS
  - Supports both x86_64 and aarch64 architectures
  - Includes automatic updates

- **Terraform**
  - Infrastructure as Code tool
  - Installed via HashiCorp repository
  - Supports multiple cloud providers

### 3. Kubernetes Tools (`provision-host-02-kubetools.sh`)

Installs Kubernetes-related tools and configurations:

- **Ansible**
  - Configuration management tool
  - Includes Kubernetes Python module
  - Configures global Ansible settings:
    - Inventory file location
    - Private key configuration
    - SSH connection settings
    - Roles path configuration

- **kubectl**
  - Kubernetes command-line tool
  - Installs via snap or direct download
  - Supports containerized environments

- **k9s**
  - Terminal UI for Kubernetes
  - Installs latest version from GitHub
  - Supports both x86_64 and aarch64 architectures

- **Helm**
  - Kubernetes package manager
  - Installs Helm 3
  - Includes automatic updates

## Usage

### Running the Installation Scripts

The scripts should be run in the following order:

1. Core software installation:
   ```bash
   ./provision-host-00-coresw.sh
   ```

2. Cloud provider tools:
   ```bash
   ./provision-host-01-cloudproviders.sh [provider]
   ```
   Where `[provider]` can be:
   - `az` or `azure` - Install Azure CLI only
   - `oci` or `oracle` - Install Oracle Cloud CLI only
   - `aws` - Install AWS CLI only
   - `gcp` or `google` - Install Google Cloud SDK only
   - `tf` or `terraform` - Install Terraform only
   - `all` - Install all cloud provider tools

3. Kubernetes tools:
   ```bash
   ./provision-host-02-kubetools.sh
   ```

### Environment Variables

- `RUNNING_IN_CONTAINER`: Set to "true" when running in a container environment
- `ARCHITECTURE`: Automatically detected system architecture

## Error Handling

Each script includes comprehensive error handling:
- Status tracking for each installation step
- Detailed error messages
- Cleanup procedures
- Installation summaries

## Architecture Support

The provision host scripts support the following architectures:
- x86_64 (AMD64)
- aarch64 (ARM64)

## Security Considerations

- Private keys are stored in `/mnt/urbalurbadisk/secrets/`
- SSH host key checking is disabled for automation
- Ansible configuration uses pipelining for better performance
- All tools are installed from official sources

## Maintenance

### Updating Tools

Most tools can be updated using their respective package managers:
- `apt` for Debian-based packages
- `snap` for snap packages
- Tool-specific update commands (e.g., `gh upgrade`)

### Troubleshooting

Common issues and solutions:
1. **Permission Issues**
   - Ensure proper sudo access
   - Check file permissions in `/mnt/urbalurbadisk/`

2. **Network Issues**
   - Verify internet connectivity
   - Check proxy settings if applicable

3. **Architecture Mismatch**
   - Verify system architecture
   - Check tool compatibility

## Best Practices

1. **Script Execution**
   - Run scripts in sequence
   - Review installation summaries
   - Check for error messages

2. **Configuration**
   - Keep sensitive data in `/mnt/urbalurbadisk/secrets/`
   - Use version control for configuration files
   - Document custom configurations

3. **Security**
   - Regularly update tools
   - Monitor for security advisories
   - Follow principle of least privilege

## Future Improvements

Planned enhancements:
- [ ] Add support for additional cloud providers
- [ ] Implement automated testing
- [ ] Add version pinning for tools
- [ ] Improve error reporting
- [ ] Add rollback capabilities