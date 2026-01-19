#!/bin/bash
# file: .devcontainer/additions/install-tool-kubernetes.sh
#
# Installs kubectl, k9s, helm and sets up .devcontainer.secrets folder for kubeconfig.
# For usage information, run: ./install-tool-kubernetes.sh --help
#
#------------------------------------------------------------------------------
# CONFIGURATION - Modify this section for each new script
#------------------------------------------------------------------------------

# --- Script Metadata ---
SCRIPT_ID="tool-kubernetes"
SCRIPT_VER="0.0.1"
SCRIPT_NAME="Kubernetes Development Tools"
SCRIPT_DESCRIPTION="Installs kubectl, k9s, helm and sets up .devcontainer.secrets folder for kubeconfig"
SCRIPT_CATEGORY="INFRA_CONFIG"
SCRIPT_CHECK_COMMAND="command -v kubectl >/dev/null 2>&1 || command -v k9s >/dev/null 2>&1 || command -v helm >/dev/null 2>&1"

# --- Extended Metadata (for website documentation) ---
SCRIPT_TAGS="kubernetes kubectl k9s helm containers orchestration"
SCRIPT_ABSTRACT="Kubernetes development tools with kubectl, k9s terminal UI, and Helm package manager."
SCRIPT_LOGO="tool-kubernetes-logo.webp"
SCRIPT_WEBSITE="https://kubernetes.io"
SCRIPT_SUMMARY="Kubernetes development toolkit including kubectl CLI for cluster management, k9s terminal UI for interactive cluster exploration, Helm for package management, and VS Code Kubernetes extension. Sets up .devcontainer.secrets for secure kubeconfig storage."
SCRIPT_RELATED="tool-iac tool-azure-dev tool-dev-utils"

# Commands for dev-setup.sh menu integration
SCRIPT_COMMANDS=(
    "Action||Install Kubernetes development tools||false|"
    "Action|--uninstall|Uninstall Kubernetes tools||false|"
    "Info|--help|Show help and usage information||false|"
)

# System packages
PACKAGES_SYSTEM=()

# Node.js packages
PACKAGES_NODE=()

# Python packages
PACKAGES_PYTHON=()

# VS Code extensions
EXTENSIONS=(
    "Kubernetes (ms-kubernetes-tools.vscode-kubernetes-tools) - Develop, deploy and debug Kubernetes applications"
    "YAML (redhat.vscode-yaml) - YAML language support with Kubernetes schema"
)

#------------------------------------------------------------------------------

# Source auto-enable library
SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
# shellcheck source=/dev/null
source "${SCRIPT_DIR}/lib/tool-auto-enable.sh"

# Source logging library
# shellcheck source=/dev/null
source "${SCRIPT_DIR}/lib/logging.sh"

#------------------------------------------------------------------------------

# --- Pre-installation/Uninstallation Setup ---
pre_installation_setup() {
    if [ "${UNINSTALL_MODE}" -eq 1 ]; then
        echo "🔧 Preparing for uninstallation..."
    else
        echo "🔧 Performing pre-installation setup..."
    fi
}

#------------------------------------------------------------------------------
# UTILITY FUNCTIONS
#------------------------------------------------------------------------------

# Centralized version checking - returns version string or empty if not installed
get_installed_kubectl_version() {
    # Check file first (more reliable immediately after install), then PATH
    if [ -x /usr/local/bin/kubectl ]; then
        /usr/local/bin/kubectl version --client 2>/dev/null | head -1 | awk '{print $3}'
    elif command -v kubectl >/dev/null 2>&1; then
        kubectl version --client 2>/dev/null | head -1 | awk '{print $3}'
    else
        echo ""
    fi
}

get_installed_k9s_version() {
    # Check file first (more reliable immediately after install), then PATH
    if [ -x /usr/local/bin/k9s ]; then
        /usr/local/bin/k9s version -s 2>/dev/null | grep Version | awk '{print $2}'
    elif command -v k9s >/dev/null 2>&1; then
        k9s version -s 2>/dev/null | grep Version | awk '{print $2}'
    else
        echo ""
    fi
}

get_installed_helm_version() {
    # Check file first (more reliable immediately after install), then PATH
    if [ -x /usr/local/bin/helm ]; then
        /usr/local/bin/helm version --short 2>/dev/null | cut -d'+' -f1
    elif command -v helm >/dev/null 2>&1; then
        helm version --short 2>/dev/null | cut -d'+' -f1
    else
        echo ""
    fi
}

#------------------------------------------------------------------------------
# CUSTOM INSTALLATION FUNCTIONS
#------------------------------------------------------------------------------

# Custom kubectl installation function
install_kubectl() {
    if [ "${UNINSTALL_MODE}" -eq 1 ]; then
        echo ""
        echo "🗑️  Removing kubectl..."
        sudo rm -f /usr/local/bin/kubectl
        echo "✅ kubectl removed"
        return
    fi

    # Check if kubectl is already installed
    local current_version
    current_version=$(get_installed_kubectl_version)
    if [ -n "$current_version" ]; then
        echo "✅ kubectl is already installed (version: ${current_version})"
        return
    fi

    echo ""
    echo "📦 Installing kubectl..."

    # Detect architecture using lib function
    local system_arch=$(detect_architecture)
    echo "   System architecture: $system_arch"

    # Download latest stable kubectl
    local stable_version=$(curl -L -s https://dl.k8s.io/release/stable.txt)
    curl -LO "https://dl.k8s.io/release/${stable_version}/bin/linux/${system_arch}/kubectl"

    # Install kubectl
    sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
    rm kubectl

    # Refresh command hash cache
    hash -r 2>/dev/null || true

    # Verify installation
    local version
    version=$(get_installed_kubectl_version)
    if [ -n "$version" ]; then
        echo "✅ kubectl installed successfully (version: ${version})"
    else
        echo "❌ kubectl installation failed"
        return 1
    fi
}

# Custom k9s installation function
install_k9s() {
    if [ "${UNINSTALL_MODE}" -eq 1 ]; then
        echo ""
        echo "🗑️  Removing k9s..."
        sudo rm -f /usr/local/bin/k9s
        echo "✅ k9s removed"
        return
    fi

    # Check if k9s is already installed
    local current_version
    current_version=$(get_installed_k9s_version)
    if [ -n "$current_version" ]; then
        echo "✅ k9s is already installed (version: ${current_version})"
        return
    fi

    echo ""
    echo "📦 Installing k9s..."

    # Detect architecture using lib function
    local system_arch=$(detect_architecture)

    # Map to k9s naming convention
    local k9s_arch
    case "$system_arch" in
        amd64)
            k9s_arch="amd64"
            ;;
        arm64)
            k9s_arch="arm64"
            ;;
        *)
            echo "❌ Unsupported architecture: $system_arch"
            return 1
            ;;
    esac

    echo "   System architecture: $system_arch (k9s: $k9s_arch)"

    # Get latest k9s release
    local k9s_version=$(curl -s https://api.github.com/repos/derailed/k9s/releases/latest | grep -o '"tag_name": "[^"]*"' | cut -d'"' -f4)

    # Download and install k9s
    curl -sL "https://github.com/derailed/k9s/releases/download/${k9s_version}/k9s_Linux_${k9s_arch}.tar.gz" | sudo tar xz -C /usr/local/bin k9s

    # Refresh command hash cache
    hash -r 2>/dev/null || true

    # Verify installation
    local version
    version=$(get_installed_k9s_version)
    if [ -n "$version" ]; then
        echo "✅ k9s installed successfully (version: ${version})"
    else
        echo "❌ k9s installation failed"
        return 1
    fi
}

# Custom helm installation function
install_helm() {
    if [ "${UNINSTALL_MODE}" -eq 1 ]; then
        echo ""
        echo "🗑️  Removing helm..."
        sudo rm -f /usr/local/bin/helm
        echo "✅ helm removed"
        return
    fi

    # Check if helm is already installed
    local current_version
    current_version=$(get_installed_helm_version)
    if [ -n "$current_version" ]; then
        echo "✅ helm is already installed (version: ${current_version})"
        return
    fi

    echo ""
    echo "📦 Installing helm..."

    # Download and install helm (official script handles architecture automatically)
    curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

    # Refresh command hash cache
    hash -r 2>/dev/null || true

    # Verify installation
    local version
    version=$(get_installed_helm_version)
    if [ -n "$version" ]; then
        echo "✅ helm installed successfully (version: ${version})"
    else
        echo "❌ helm installation failed"
        return 1
    fi
}

# Setup kubeconfig directory
setup_kubeconfig() {
    if [ "${UNINSTALL_MODE}" -eq 1 ]; then
        return
    fi

    echo ""
    echo "🔧 Setting up kubeconfig directory..."

    # Create .devcontainer.secrets/.kube directory
    mkdir -p /workspace/.devcontainer.secrets/.kube

    # Create symlink from ~/.kube to .devcontainer.secrets/.kube
    if [ ! -L "$HOME/.kube" ]; then
        ln -sf /workspace/.devcontainer.secrets/.kube "$HOME/.kube"
        echo "✅ Kubeconfig directory linked to .devcontainer.secrets/.kube"
    else
        echo "✅ Kubeconfig symlink already exists"
    fi

    # Create helper scripts for copying kubeconfig from host
    create_kubeconfig_helper_scripts
}

# Create helper scripts for copying kubeconfig from host
create_kubeconfig_helper_scripts() {
    echo ""
    echo "📝 Creating kubeconfig helper scripts..."

    # Create Mac helper script
    cat > /workspace/.devcontainer.secrets/.kube/copy-kubeconfig-mac.sh << 'EOF'
#!/bin/bash
# file: .devcontainer.secrets/.kube/copy-kubeconfig-mac.sh
# Copies ~/.kube/config to .devcontainer.secrets/.kube/config
# CRITICAL: Rewrites server URLs to use host.docker.internal for container access

set -e

echo "🔐 Setting up Kubernetes credentials for devcontainer..."

# Check if source kubeconfig exists
if [ ! -f "$HOME/.kube/config" ]; then
    echo "❌ Error: ~/.kube/config not found"
    echo "   Make sure Rancher Desktop or Docker Desktop is installed"
    exit 1
fi

# Get script directory
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Create target directory
mkdir -p "$SCRIPT_DIR/.kube"

# Copy and rewrite server URLs for container access
echo "📝 Copying and rewriting kubeconfig for devcontainer networking..."

# Copy file
cp "$HOME/.kube/config" "$SCRIPT_DIR/.kube/config"

# Rewrite server URLs to use host.docker.internal
# This is CRITICAL because 127.0.0.1/localhost inside container != host
sed -i.bak \
    -e 's|https://127\.0\.0\.1:|https://host.docker.internal:|g' \
    -e 's|https://localhost:|https://host.docker.internal:|g' \
    -e 's|https://0\.0\.0\.0:|https://host.docker.internal:|g' \
    -e 's|https://kubernetes\.docker\.internal:|https://host.docker.internal:|g' \
    -e 's|insecure-skip-tls-verify: false|insecure-skip-tls-verify: true|g' \
    -e 's|^      certificate-authority-data:.*|      # certificate-authority-data: (commented out for insecure-skip-tls-verify)|g' \
    "$SCRIPT_DIR/.kube/config"

# Remove backup file
rm -f "$SCRIPT_DIR/.kube/config.bak"

echo "✅ Kubeconfig copied to .devcontainer.secrets/.kube/config"
echo "✅ Server URLs rewritten to use host.docker.internal"
echo ""
echo "Next steps:"
echo "1. Open this project in VSCode devcontainer"
echo "2. Run: bash .devcontainer/additions/install-tool-kubernetes.sh"
echo "3. The installer creates a symlink: ~/.kube -> /workspace/.devcontainer.secrets/.kube"
echo "4. Test: kubectl get nodes"
echo ""
echo "Note: Server URLs have been rewritten for container networking."
echo "      Original: https://127.0.0.1:6443"
echo "      Rewritten: https://host.docker.internal:6443"
EOF

    chmod +x /workspace/.devcontainer.secrets/.kube/copy-kubeconfig-mac.sh

    # Create Windows helper script
    cat > /workspace/.devcontainer.secrets/.kube/copy-kubeconfig-win.ps1 << 'EOF'
# file: .devcontainer.secrets/.kube/copy-kubeconfig-win.ps1
# Copies %USERPROFILE%\.kube\config to .devcontainer.secrets\.kube\config
# CRITICAL: Rewrites server URLs to use host.docker.internal for container access

Write-Host "🔐 Setting up Kubernetes credentials for devcontainer..." -ForegroundColor Cyan

$sourceConfig = Join-Path $env:USERPROFILE ".kube\config"

if (-not (Test-Path $sourceConfig)) {
    Write-Host "❌ Error: $sourceConfig not found" -ForegroundColor Red
    Write-Host "   Make sure Rancher Desktop or Docker Desktop is installed" -ForegroundColor Yellow
    exit 1
}

# Get script directory
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

# Create target directory
$targetDir = Join-Path $scriptDir ".kube"
New-Item -ItemType Directory -Force -Path $targetDir | Out-Null

# Copy config
$targetConfig = Join-Path $targetDir "config"
Copy-Item $sourceConfig $targetConfig

# Rewrite server URLs for container access
Write-Host "📝 Rewriting kubeconfig for devcontainer networking..." -ForegroundColor Cyan

# Read config file
$content = Get-Content $targetConfig -Raw

# Rewrite server URLs to use host.docker.internal
# This is CRITICAL because 127.0.0.1/localhost inside container != host
$content = $content -replace 'https://127\.0\.0\.1:', 'https://host.docker.internal:'
$content = $content -replace 'https://localhost:', 'https://host.docker.internal:'
$content = $content -replace 'https://0\.0\.0\.0:', 'https://host.docker.internal:'
$content = $content -replace 'https://kubernetes\.docker\.internal:', 'https://host.docker.internal:'

# Enable insecure-skip-tls-verify for local development
# Rancher Desktop certs don't include host.docker.internal in SAN
$content = $content -replace 'insecure-skip-tls-verify: false', 'insecure-skip-tls-verify: true'

# Comment out certificate-authority-data (kubectl doesn't allow both)
$content = $content -replace '(?m)^      certificate-authority-data:.*$', '      # certificate-authority-data: (commented out for insecure-skip-tls-verify)'

# Write back
$content | Set-Content $targetConfig -NoNewline

Write-Host "✅ Kubeconfig copied to .devcontainer.secrets\.kube\config" -ForegroundColor Green
Write-Host "✅ Server URLs rewritten to use host.docker.internal" -ForegroundColor Green
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Cyan
Write-Host "1. Open this project in VSCode devcontainer"
Write-Host "2. Run: bash .devcontainer/additions/install-tool-kubernetes.sh"
Write-Host "3. The installer creates a symlink: ~/.kube -> /workspace/.devcontainer.secrets/.kube"
Write-Host "4. Test: kubectl get nodes"
Write-Host ""
Write-Host "Note: Server URLs have been rewritten for container networking." -ForegroundColor Yellow
Write-Host "      Original: https://127.0.0.1:6443" -ForegroundColor Yellow
Write-Host "      Rewritten: https://host.docker.internal:6443" -ForegroundColor Yellow
EOF

    echo "✅ Created copy-kubeconfig-mac.sh"
    echo "✅ Created copy-kubeconfig-win.ps1"
}

# --- Post-installation/Uninstallation Messages ---
post_installation_message() {
    echo
    echo "🎉 Installation complete!"
    echo
    echo "Quick start:"
    echo "  - kubectl version: kubectl version --client"
    echo "  - k9s version:     k9s version"
    echo "  - helm version:    helm version"
    echo "  - Launch k9s:      k9s"
    echo
    echo "To connect to your Kubernetes cluster:"
    echo "  1. On your host (Mac/Windows), run:"
    echo "     Mac:     bash .devcontainer.secrets/.kube/copy-kubeconfig-mac.sh"
    echo "     Windows: powershell .devcontainer.secrets/.kube/copy-kubeconfig-win.ps1"
    echo "  2. In devcontainer: kubectl get nodes"
    echo
    echo "Docs: https://kubernetes.io/docs/reference/kubectl/"
    echo "      https://k9scli.io/"
    echo "      https://helm.sh/docs/"
    echo
}

post_uninstallation_message() {
    echo
    echo "🏁 Uninstallation complete!"
    echo
    echo "Note: Kubeconfig directory in .devcontainer.secrets/.kube remains"
    echo
}

#------------------------------------------------------------------------------
# ARGUMENT PARSING
#------------------------------------------------------------------------------

# Initialize mode flags
DEBUG_MODE=0
UNINSTALL_MODE=0
FORCE_MODE=0

# Source common installation patterns library (needed for --help)
source "${SCRIPT_DIR}/lib/install-common.sh"

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --help)
            show_script_help
            exit 0
            ;;
        --debug)
            DEBUG_MODE=1
            shift
            ;;
        --uninstall)
            UNINSTALL_MODE=1
            shift
            ;;
        --force)
            FORCE_MODE=1
            shift
            ;;
        *)
            echo "ERROR: Unknown option: $1" >&2
            echo "Usage: $0 [--help] [--debug] [--uninstall] [--force]" >&2
            echo "Description: $SCRIPT_DESCRIPTION"
            exit 1
            ;;
    esac
done

# Export mode flags
export DEBUG_MODE
export UNINSTALL_MODE
export FORCE_MODE

#------------------------------------------------------------------------------
# SOURCE CORE SCRIPTS
#------------------------------------------------------------------------------

# Source core installation scripts
source "${SCRIPT_DIR}/lib/core-install-system.sh"
source "${SCRIPT_DIR}/lib/core-install-node.sh"
source "${SCRIPT_DIR}/lib/core-install-extensions.sh"
source "${SCRIPT_DIR}/lib/core-install-pwsh.sh"
source "${SCRIPT_DIR}/lib/core-install-python.sh"

# Note: lib/install-common.sh already sourced earlier (needed for --help)

#------------------------------------------------------------------------------
# HELPER FUNCTIONS
#------------------------------------------------------------------------------

# Function to process installations
process_installations() {
    # Custom Kubernetes tools installation
    install_kubectl
    install_k9s
    install_helm
    setup_kubeconfig

    # Then use standard processing from lib/install-common.sh
    process_standard_installations
}

#------------------------------------------------------------------------------
# MAIN EXECUTION
#------------------------------------------------------------------------------

if [ "${UNINSTALL_MODE}" -eq 1 ]; then
    show_install_header "uninstall"
    pre_installation_setup
    process_installations
    post_uninstallation_message

    # Remove from auto-enable config
    auto_disable_tool
else
    show_install_header
    pre_installation_setup
    process_installations
    post_installation_message

    # Auto-enable for container rebuild
    auto_enable_tool
fi

echo "✅ Script execution finished."
exit 0
