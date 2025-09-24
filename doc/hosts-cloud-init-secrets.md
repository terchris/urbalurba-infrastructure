# Cloud-Init SSH Key Setup

**File**: `doc/hosts-cloud-init-secrets.md`
**Purpose**: SSH key generation for cloud-init and Ansible automation
**Target Audience**: Infrastructure engineers setting up cloud-init deployments
**Last Updated**: September 22, 2024

## 📋 Overview

All VMs that we create are configured using cloud-init.yml. An "ansible" user is created and set up so that it can log in using SSH key authentication. This document provides instructions for creating the SSH key that is used by ansible to connect to all hosts.

This is a **prerequisite step** for cloud-init deployment - see [hosts-cloud-init-readme.md](./hosts-cloud-init-readme.md) for the main cloud-init documentation.

> **Important:** The SSH key files (`id_rsa_ansible` and `id_rsa_ansible.pub`) will be created on your local disk and should never be committed to the repository. They contain sensitive authentication credentials.

## Prerequisites

First, change directory to the secrets directory:

```bash
cd secrets
pwd
```

You MUST be in the folder `secrets` for the rest of the commands to work.

## Creating the Ansible SSH Keys

There are two methods to create the necessary SSH keys:

### Method 1: Using the Automated Script (Recommended)

We've created a script that automates the key creation process:

```bash
./create-secrets.sh
```

The script will:
1. Verify it's running from the correct directory
2. Create an RSA 4096-bit key pair without a passphrase
3. Verify the keys were created successfully
4. Provide a summary of operations

If successful, you'll see a message indicating "All OK".

### Method 2: Manual Creation

If you prefer to create the keys manually:

```bash
ssh-keygen -t rsa -b 4096 -f ./id_rsa_ansible
```

When prompted for a passphrase, you can leave it empty.

```text
Generating public/private rsa key pair.
Enter passphrase (empty for no passphrase): 
Enter same passphrase again: 
Your identification has been saved in ./id_rsa_ansible
Your public key has been saved in ./id_rsa_ansible.pub
```

## Using the Generated Keys

The public key (id_rsa_ansible.pub) is what you'll add to your cloud-init.yml file. You can view it with:

```bash
cat ./id_rsa_ansible.pub
```

For security, the private key must be set to read-only for the user:

```bash
chmod 400 ./id_rsa_ansible
```

After setting permissions, your key files should appear like this:

```bash
ls -la
```

```text
-r--------  1 user  staff  3401 Jun  7 12:27 id_rsa_ansible
-rw-r--r--  1 user  staff   755 Jun  7 12:27 id_rsa_ansible.pub
```

## Using the Key to Connect

To log in to a host with the username ansible using this key:

```bash
ssh -i ./id_rsa_ansible ansible@<ip or hostname>
```
