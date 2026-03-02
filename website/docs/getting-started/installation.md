# Installation Guide

**File**: `docs/overview-installation.md`
**Purpose**: Simple installation guide for Urbalurba Infrastructure
**Target Audience**: New users and developers getting started
**Last Updated**: September 22, 2024

## 📋 Overview

Urbalurba Infrastructure provides a complete datacenter environment on your laptop using Kubernetes and Docker. Installation requires just two steps: install Rancher Desktop, then download and run our installation script.

## 🛠️ Prerequisites

- **Operating System**: macOS, Windows, or Linux
- **Hardware**: 8GB+ RAM recommended, 10GB+ free disk space
- **Internet Connection**: Required for downloading components

## 📦 Step 1: Install Rancher Desktop

Rancher Desktop provides Kubernetes and Docker for your local development environment.

1. **Download Rancher Desktop** from the official website:
   - 🌐 **https://rancherdesktop.io/**

2. **Install and configure**:
   - Follow the installation instructions for your operating system
   - Start Rancher Desktop and enable Kubernetes
   - Allocate at least **8GB RAM** and **4 CPU cores** for optimal performance

3. **Verify installation**:
   ```bash
   # Check that Kubernetes is running
   kubectl version --client

   # Check that Docker is available
   docker version
   ```

> 📝 **Note**: If you have Docker Desktop installed, uninstall it first as it conflicts with Rancher Desktop.

## 🚀 Step 2: Download Urbalurba Infrastructure

Download the latest release ZIP file from GitHub:

1. **Go to releases page**: https://github.com/terchris/urbalurba-infrastructure/releases
2. **Download the latest release**: Click on `urbalurba-infrastructure.zip`
3. **Extract the ZIP file** to your desired folder

Or use command line:

```bash
# Download latest release
curl -L https://github.com/terchris/urbalurba-infrastructure/releases/latest/download/urbalurba-infrastructure.zip -o urbalurba-infrastructure.zip

# Extract
unzip urbalurba-infrastructure.zip

# Navigate into the folder
cd urbalurba-infrastructure
```

### What You Get

The infrastructure package contains:
- **Kubernetes manifests** - All service definitions
- **Provision scripts** - Setup and management tools
- **Documentation** - Complete guides and references
- **Configuration files** - Ready-to-use configurations

## ✅ Verification

After downloading and extracting, verify you have the infrastructure package:

```bash
# Check the main folders are present
ls -la urbalurba-infrastructure/
```

## 🌐 Next Steps - Deploy Services

After downloading the infrastructure package, you'll need to deploy the services to your Kubernetes cluster:

1. **Follow the [Getting Started Guide](./overview.md)** in the downloaded package for deployment instructions
2. **Use the provision scripts** to set up and deploy services
3. **Access services** once deployed at `*.localhost` domains:


