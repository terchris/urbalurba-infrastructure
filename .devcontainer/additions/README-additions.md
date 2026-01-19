# Devcontainer Additions System

This folder contains install scripts, configuration scripts, and services for your devcontainer.

---

## Quick Start

Use the interactive menu to manage tools and services:

```bash
dev-setup
```

This displays all available components with their status (✅ installed, ❌ not installed).

---

## Script Types

| Type | Pattern | Purpose | Example |
|------|---------|---------|---------|
| Install | `install-*.sh` | Install tools and runtimes | `install-dev-python.sh` |
| Config | `config-*.sh` | Configure settings and credentials | `config-devcontainer-identity.sh` |
| Service | `service-*.sh` | Manage background services | `service-nginx.sh` |

---

## Running Scripts Directly

```bash
# Install a tool
.devcontainer/additions/install-dev-python.sh

# Configure a setting
.devcontainer/additions/config-devcontainer-identity.sh

# Manage a service
.devcontainer/additions/service-nginx.sh --start
.devcontainer/additions/service-nginx.sh --stop
.devcontainer/additions/service-nginx.sh --status
```

---

## Auto-Installation

Tools and services can be auto-installed on container rebuild:

- **Tools**: Listed in `.devcontainer.extend/enabled-tools.conf`
- **Services**: Listed in `.devcontainer.extend/enabled-services.conf`

These files are automatically managed when you install tools via `dev-setup`.

---

## Categories

Scripts are organized by category in the menu:

| Category | Content |
|----------|---------|
| Development Tools | Programming languages (Python, Go, TypeScript, etc.) |
| AI & ML Tools | AI tools (Claude Code, etc.) |
| Cloud Tools | Cloud platforms (Azure, AWS, etc.) |
| Data Analytics | Data tools (Jupyter, pandas, etc.) |
| Infrastructure | DevOps tools (Kubernetes, Terraform, etc.) |
| Services | Background services (nginx, monitoring, etc.) |

---

## Directory Structure

```
.devcontainer/additions/
├── install-*.sh              # Tool installation scripts
├── config-*.sh               # Configuration scripts
├── service-*.sh              # Service management scripts
├── lib/                      # Shared libraries
├── nginx/                    # Nginx configuration
├── otel/                     # OpenTelemetry configuration
├── addition-templates/       # Templates for new scripts
└── tests/                    # Test suite
```

---

## For Contributors

Want to add new tools or modify scripts? See the contributor documentation:

- [Adding Tools](../../docs/contributors/adding-tools.md) - How to add new scripts
- [Creating Install Scripts](../../docs/contributors/creating-install-scripts.md) - Detailed install script guide
- [Creating Service Scripts](../../docs/contributors/creating-service-scripts.md) - Service script guide
- [Libraries Reference](../../docs/contributors/libraries.md) - Shared library functions
- [Architecture](../../docs/contributors/architecture.md) - System architecture
- [Testing](../../docs/contributors/testing.md) - Test framework
