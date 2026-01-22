#!/bin/bash
# install.sh - UIS (Urbalurba Infrastructure Stack) Installer
#
# Usage: curl -fsSL https://uis.sovereignsky.no/install.sh | bash
#
# This script:
# 1. Checks prerequisites (Docker installed and running)
# 2. Pulls the UIS container image
# 3. Creates the ./uis wrapper script in the current directory
#
# After installation:
#   ./uis start        # Start the UIS container
#   ./uis deploy       # Deploy default services
#   ./uis setup        # Interactive configuration

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BOLD='\033[1m'
NC='\033[0m' # No Color

log_info() { echo -e "${GREEN}[UIS]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[UIS]${NC} $1"; }
log_error() { echo -e "${RED}[UIS]${NC} $1"; }

# Banner
echo ""
echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BOLD}  UIS - Urbalurba Infrastructure Stack Installer${NC}"
echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# Detect platform
detect_platform() {
    case "$(uname -s)" in
        Linux*)
            if grep -q Microsoft /proc/version 2>/dev/null; then
                echo "wsl2"
            else
                echo "linux"
            fi
            ;;
        Darwin*) echo "macos" ;;
        MINGW*|MSYS*|CYGWIN*) echo "windows-gitbash" ;;
        *) echo "unknown" ;;
    esac
}

PLATFORM=$(detect_platform)
log_info "Detected platform: $PLATFORM"

# Check Docker is installed
check_docker_installed() {
    if ! command -v docker &> /dev/null; then
        log_error "Docker is not installed!"
        echo ""
        case "$PLATFORM" in
            macos)
                echo "Please install Docker Desktop or Rancher Desktop:"
                echo "  • Rancher Desktop: https://rancherdesktop.io/"
                echo "  • Docker Desktop: https://www.docker.com/products/docker-desktop/"
                ;;
            linux)
                echo "Please install Docker:"
                echo "  • Docker Engine: https://docs.docker.com/engine/install/"
                echo "  • Rancher Desktop: https://rancherdesktop.io/"
                ;;
            wsl2)
                echo "Please install Docker Desktop for Windows or Rancher Desktop:"
                echo "  • Rancher Desktop: https://rancherdesktop.io/"
                echo "  • Docker Desktop: https://www.docker.com/products/docker-desktop/"
                echo ""
                echo "Make sure to enable WSL2 integration in settings."
                ;;
            *)
                echo "Please install Docker: https://docs.docker.com/get-docker/"
                ;;
        esac
        exit 1
    fi
}

# Check Docker is running
check_docker_running() {
    if ! docker info &> /dev/null; then
        log_error "Docker is not running!"
        echo ""
        case "$PLATFORM" in
            macos)
                echo "Please start Docker Desktop or Rancher Desktop."
                echo "You can find it in your Applications folder."
                ;;
            linux)
                echo "Please start the Docker daemon:"
                echo "  sudo systemctl start docker"
                ;;
            wsl2)
                echo "Please start Docker Desktop for Windows."
                echo "Make sure WSL2 integration is enabled in Docker Desktop settings."
                ;;
            *)
                echo "Please start the Docker daemon."
                ;;
        esac
        exit 1
    fi
}

# Check disk space (need ~2GB)
check_disk_space() {
    local required_mb=2000
    local available_mb

    if command -v df &> /dev/null; then
        # Get available space in current directory (in MB)
        available_mb=$(df -m . | awk 'NR==2 {print $4}')

        if [[ "$available_mb" -lt "$required_mb" ]]; then
            log_warn "Low disk space: ${available_mb}MB available, ${required_mb}MB recommended"
            echo "The UIS container image requires approximately 2GB of disk space."
            read -p "Continue anyway? [y/N] " -n 1 -r
            echo
            if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                exit 1
            fi
        fi
    fi
}

# Run checks
log_info "Checking prerequisites..."
check_docker_installed
check_docker_running
check_disk_space

# Pull container image
IMAGE="ghcr.io/terchris/uis-provision-host:latest"
log_info "Pulling UIS container image..."
echo "  This may take a few minutes (~2GB download)"
echo ""

if ! docker pull "$IMAGE"; then
    log_error "Failed to pull container image"
    echo ""
    echo "This could be due to:"
    echo "  • Network connectivity issues"
    echo "  • GitHub Container Registry rate limiting"
    echo ""
    echo "Try again in a few minutes, or check your network connection."
    exit 1
fi

log_info "Container image pulled successfully"

# Download wrapper script
log_info "Creating ./uis wrapper script..."
curl -fsSL "https://uis.sovereignsky.no/uis" -o ./uis
chmod +x ./uis

# Success message
echo ""
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}  ✓ UIS installed successfully!${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo "Next steps:"
echo ""
echo "  ${BOLD}./uis start${NC}        Start the UIS container"
echo "  ${BOLD}./uis deploy${NC}       Deploy default services (nginx)"
echo "  ${BOLD}./uis setup${NC}        Interactive configuration menu"
echo ""
echo "Quick start:"
echo "  ${BOLD}./uis start && ./uis deploy${NC}"
echo ""
echo "Documentation: https://uis.sovereignsky.no"
echo ""
