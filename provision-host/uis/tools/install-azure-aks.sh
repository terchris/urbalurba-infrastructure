#!/bin/bash
# install-azure-aks.sh - AKS dependencies meta-installer

# === Tool Metadata ===
TOOL_ID="azure-aks"
TOOL_NAME="Azure AKS dependencies"
TOOL_DESCRIPTION="Bundle: azure-cli + opentofu (everything ./uis platform <verb> azure-aks needs)"
TOOL_CATEGORY="META"
TOOL_CHECK_COMMAND="command -v az >/dev/null && command -v tofu >/dev/null"
TOOL_SIZE="~667MB (637 + 30)"
TOOL_WEBSITE="https://learn.microsoft.com/azure/aks/"

# Contract:
#   - do_install MUST exit non-zero on any failure (set -euo pipefail).
#   - Idempotency is enforced by the wrapper (tool-installation.sh:194) via
#     TOOL_CHECK_COMMAND — do not add an "already installed" guard here.
#   - Meta-installer: do_install delegates to install_tool for each component.
#     Component idempotency is handled inside install_tool, so re-runs skip
#     already-installed components automatically. Sequential statements (not
#     &&-chained) so set -e aborts on the first failure.

do_install() {
    set -euo pipefail
    echo "Installing Azure AKS dependencies (azure-cli + opentofu)..."
    install_tool azure-cli
    install_tool opentofu
}

do_uninstall() {
    set -euo pipefail
    echo "azure-aks is a bundle. To uninstall its components, run:"
    echo "  ./uis tools uninstall azure-cli"
    echo "  ./uis tools uninstall opentofu"
    echo "(left as separate commands so you don't accidentally remove a component"
    echo " you still want for other purposes.)"
}
