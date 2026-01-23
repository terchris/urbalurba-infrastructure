# install.ps1 - UIS (Urbalurba Infrastructure Stack) Installer for Windows
#
# Usage:
#   Invoke-WebRequest https://uis.sovereignsky.no/install.ps1 -OutFile install.ps1; .\install.ps1
#
# Or in one line:
#   iwr https://uis.sovereignsky.no/install.ps1 -OutFile install.ps1; .\install.ps1
#
# This script:
# 1. Checks prerequisites (Docker installed and running)
# 2. Pulls the UIS container image
# 3. Creates the wrapper scripts in the current directory

$ErrorActionPreference = "Stop"

# Banner
Write-Host ""
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
Write-Host "  UIS - Urbalurba Infrastructure Stack Installer" -ForegroundColor Cyan
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
Write-Host ""

function Write-Info { param($Message) Write-Host "[UIS] $Message" -ForegroundColor Green }
function Write-Warn { param($Message) Write-Host "[UIS] $Message" -ForegroundColor Yellow }
function Write-Err { param($Message) Write-Host "[UIS] $Message" -ForegroundColor Red }

# Check Docker is installed
function Test-DockerInstalled {
    try {
        $null = Get-Command docker -ErrorAction Stop
        return $true
    } catch {
        return $false
    }
}

# Check Docker is running
function Test-DockerRunning {
    try {
        $null = docker info 2>&1
        return $LASTEXITCODE -eq 0
    } catch {
        return $false
    }
}

Write-Info "Checking prerequisites..."

if (-not (Test-DockerInstalled)) {
    Write-Err "Docker is not installed!"
    Write-Host ""
    Write-Host "Please install Docker Desktop or Rancher Desktop:"
    Write-Host "  • Rancher Desktop: https://rancherdesktop.io/"
    Write-Host "  • Docker Desktop: https://www.docker.com/products/docker-desktop/"
    Write-Host ""
    Write-Host "After installation, restart this script."
    exit 1
}

if (-not (Test-DockerRunning)) {
    Write-Err "Docker is not running!"
    Write-Host ""
    Write-Host "Please start Docker Desktop or Rancher Desktop."
    Write-Host "You can find it in the Start Menu or System Tray."
    Write-Host ""
    Write-Host "After starting Docker, restart this script."
    exit 1
}

Write-Info "Docker is available"

# Pull container image
$Image = "ghcr.io/terchris/uis-provision-host:latest"
Write-Info "Pulling UIS container image..."
Write-Host "  This may take a few minutes (~2GB download)"
Write-Host ""

docker pull $Image
if ($LASTEXITCODE -ne 0) {
    Write-Err "Failed to pull container image"
    Write-Host ""
    Write-Host "This could be due to:"
    Write-Host "  • Network connectivity issues"
    Write-Host "  • GitHub Container Registry rate limiting"
    Write-Host ""
    Write-Host "Try again in a few minutes, or check your network connection."
    exit 1
}

Write-Info "Container image pulled successfully"

# Download wrapper scripts
Write-Info "Downloading wrapper scripts..."

$BaseUrl = "https://uis.sovereignsky.no"

try {
    Invoke-WebRequest -Uri "$BaseUrl/uis.ps1" -OutFile ".\uis.ps1" -UseBasicParsing
    Invoke-WebRequest -Uri "$BaseUrl/uis.cmd" -OutFile ".\uis.cmd" -UseBasicParsing
    Write-Info "Created uis.ps1 and uis.cmd"
} catch {
    Write-Err "Failed to download wrapper scripts: $_"
    exit 1
}

# Success message
Write-Host ""
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Green
Write-Host "  ✓ UIS installed successfully!" -ForegroundColor Green
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Green
Write-Host ""
Write-Host "Next steps:"
Write-Host ""
Write-Host "  " -NoNewline; Write-Host ".\uis.ps1 start" -ForegroundColor White -NoNewline; Write-Host "        Start the UIS container"
Write-Host "  " -NoNewline; Write-Host ".\uis.ps1 deploy" -ForegroundColor White -NoNewline; Write-Host "       Deploy default services (nginx)"
Write-Host "  " -NoNewline; Write-Host ".\uis.ps1 setup" -ForegroundColor White -NoNewline; Write-Host "        Interactive configuration menu"
Write-Host ""
Write-Host "Or from Command Prompt:"
Write-Host "  " -NoNewline; Write-Host "uis start" -ForegroundColor White -NoNewline; Write-Host "              (same commands without .ps1)"
Write-Host ""
Write-Host "Quick start:"
Write-Host "  " -NoNewline; Write-Host ".\uis.ps1 start; .\uis.ps1 deploy" -ForegroundColor White
Write-Host ""
Write-Host "Documentation: https://uis.sovereignsky.no"
Write-Host ""
