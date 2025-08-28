# Installation Guide

This guide walks you through installing Urbalurba Infrastructure on your local machine.

## Prerequisites

- macOS 10.15 or later (Windows support coming soon)
- At least 8GB free disk space
- Uninstall Docker Desktop if present (conflicts with Rancher Desktop)

## Quick Install

Run this single command to download and start the installer:

```bash
curl -L https://raw.githubusercontent.com/terchris/urbalurba-infrastructure/main/install-urbalurba.sh -o install-urbalurba.sh && chmod +x install-urbalurba.sh && ./install-urbalurba.sh
```

## What the Installer Does

1. Sets up prerequisites (Homebrew, Xcode tools) and checks for Docker Desktop
2. Installs Rancher Desktop and configures Kubernetes + Docker
3. Installs k9s for terminal-based cluster management
4. Downloads the latest Urbalurba infrastructure packages and configs
5. Applies Kubernetes manifests to provision services
6. Creates the provision-host container for ongoing management

## Installation Options

```bash
# Interactive (asks permission at each step)
./install-urbalurba.sh

# Automatic (no prompts)
./install-urbalurba.sh --auto

# Preview only (show what would be installed)
./install-urbalurba.sh --commands
```

## Next Steps

- Read how the system fits together in [How It Works](HOW_IT_WORKS.md)
- Learn how to access tools inside the management container in [Provision Host Documentation](provision-host-readme.md)
- Troubleshooting? See [Troubleshooting](troubleshooting-readme.md)

