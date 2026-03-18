---
title: Template Catalog
sidebar_label: Template Catalog
sidebar_position: 2
---

# Template Catalog

All templates produce a project with the same structure: application code, a Dockerfile, Kubernetes manifests, and a GitHub Actions workflow. They differ only in language and framework.

## Available Templates

| Template | Language / Framework | Port | Description |
|----------|---------------------|------|-------------|
| `typescript-basic-webserver` | TypeScript / Express | 3000 | Node.js web server with hot reload |
| `python-basic-webserver` | Python / Flask | 6000 | Flask web server with auto-reload |
| `golang-basic-webserver` | Go / net/http | 3000 | Go web server with health checks |
| `java-basic-webserver` | Java / Spring Boot | 3000 | Spring Boot web server with Actuator |
| `csharp-basic-webserver` | C# / ASP.NET Core | 3000 | ASP.NET Core web server with hot reload |
| `php-basic-webserver` | PHP / built-in server | 3000 | PHP built-in web server |
| `designsystemet-basic-react-app` | TypeScript / React + Vite | 3000 | React app using Digdir Designsystemet components |

## What every template includes

| Component | Purpose |
|-----------|---------|
| Application code | A "Hello World" web server in the template's language |
| `Dockerfile` | Builds the app into a container image |
| `manifests/deployment.yaml` | Kubernetes Deployment and Service definitions |
| `manifests/kustomization.yaml` | Resource list for ArgoCD sync |
| `.github/workflows/` | GitHub Actions pipeline to build, push, and update manifests |
| README | Template-specific getting started instructions |

## Docker build patterns

Templates use two build approaches depending on the language:

**Single-stage** (TypeScript, Python, PHP, React): The Dockerfile installs dependencies and runs the app directly.

**Multi-stage** (Go, Java, C#): A build stage compiles the application, then a minimal runtime stage copies only the binary. This produces smaller container images.

## Full list

The templates are maintained in the [urbalurba-dev-templates](https://github.com/helpers-no/dev-templates) repository. Check there for the latest templates and detailed README files for each one.
