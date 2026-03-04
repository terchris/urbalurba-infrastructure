---
title: Dev Templates
sidebar_label: Dev Templates
sidebar_position: 1
---

# Dev Templates

Dev templates give you a ready-to-run project with a web server, Dockerfile, Kubernetes manifests, and a GitHub Actions CI/CD pipeline. You pick a language, run one command, and start coding.

## Prerequisites

You need the [devcontainer-toolbox](https://github.com/norwegianredcross/devcontainer-toolbox) set up in your development environment. It provides the `dev-template.sh` script that initializes projects from templates.

## Creating a new project

From your devcontainer terminal, run:

```bash
.devcontainer/dev/dev-template.sh
```

A menu appears with all available templates grouped by category:

```plaintext
Choose a template (ESC to cancel):

🌐=Web Server  📱=Web App  📦=Other

  🌐 C# Basic Webserver
  🌐 Go Basic Webserver
  🌐 Java Basic Webserver
  🌐 PHP Basic Webserver
  🌐 Python Basic Webserver
  🌐 TypeScript Basic Webserver
  📱 Designsystemet Basic React App
```

Select a template and confirm. The script copies the template files into your workspace and sets up the project structure.

You can also skip the menu by passing the template name directly:

```bash
.devcontainer/dev/dev-template.sh typescript-basic-webserver
```

## What you get

After initialization, your project contains:

```plaintext
your-project/
├── app/                        # Application source code
├── manifests/
│   ├── deployment.yaml         # Kubernetes Deployment + Service
│   └── kustomization.yaml      # For ArgoCD compatibility
├── .github/
│   └── workflows/
│       └── build-and-push.yaml # GitHub Actions CI/CD pipeline
├── Dockerfile                  # Container build
└── README-<template>.md        # Template-specific documentation
```

Each piece serves a role in the pipeline:

| File | Purpose |
|------|---------|
| `app/` | Your application code — edit this |
| `Dockerfile` | Builds your app into a container image |
| `.github/workflows/` | Automatically builds and pushes on every commit to main |
| `manifests/deployment.yaml` | Tells Kubernetes how to run your container |
| `manifests/kustomization.yaml` | Lets ArgoCD discover and sync your manifests |

## Running locally

Each template includes instructions for running the app locally without Kubernetes. For example, for the TypeScript template:

```bash
npm install
npm run dev
```

The app starts on `http://localhost:3000` (port varies by template — check the README).

## Next steps

- Browse the [Template Catalog](template-catalog.md) to see all available templates
- Learn how the [CI/CD Pipeline](argocd-pipeline.md) builds and deploys your code
- Use the [ArgoCD Commands](argocd-commands.md) to register your app on the cluster
