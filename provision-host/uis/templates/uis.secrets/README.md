# UIS Secrets Directory

This directory contains machine-local secrets and generated sensitive artifacts used by UIS.

It is automatically added to `.gitignore` and must never be committed.

## Source of Truth

The full documentation for this folder lives in:

- `website/docs/contributors/architecture/secrets.md`

That document is the canonical reference for:

- cluster-deployed secrets generated into Kubernetes
- `uis-provision-host` runtime and provisioning secrets
- generated kubeconfig and cloud-init artifacts
- which folders are user-edited, generated, active, optional, or currently unclear

## Most Common Workflow

If you want to change cluster secret values:

```bash
# 1. Edit your values
nano .uis.secrets/secrets-config/00-common-values.env.template

# 2. Regenerate Kubernetes secrets
./uis secrets generate

# 3. Apply to cluster
./uis secrets apply
```

## Find Current Credentials

If you want to know which usernames, emails, or passwords your current machine is using, check:

- `.uis.secrets/secrets-config/00-common-values.env.template`

If you want to see the built-in development defaults UIS ships with, check:

- `provision-host/uis/templates/default-secrets.env`

The machine-local `.uis.secrets/secrets-config/00-common-values.env.template` file is the more important one after UIS has been initialized.

If you have just started UIS and have not changed any secrets yet:

- you can use the default development credentials and play around
- the shipped defaults are listed in `provision-host/uis/templates/default-secrets.env`
- the active values for this machine are in `.uis.secrets/secrets-config/00-common-values.env.template`

If the two files differ, trust `.uis.secrets/secrets-config/00-common-values.env.template`.

## Local Folder Hints

- `secrets-config/` — user-edited source values for cluster secrets
- `generated/` — generated output, do not edit directly
- `ssh/` — SSH keys used for VM/device provisioning
- `cloud-accounts/` — cloud provider credentials
- `service-keys/` — service-specific runtime/provisioning keys
- `network/` — network-related credentials

See the architecture doc for the exact meaning and status of each folder.

## Safety Rules

- Edit source files, not generated files
- Never commit `.uis.secrets/`
- Treat this folder as machine-local state
