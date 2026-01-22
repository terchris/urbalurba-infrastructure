# uis.ps1 - Urbalurba Infrastructure Stack CLI wrapper for Windows PowerShell
#
# This script manages the UIS provision-host container and routes
# commands to uis-cli.sh running inside the container.
#
# Usage: .\uis.ps1 <command> [args]
# Run .\uis.ps1 help for available commands

param(
    [Parameter(Position=0)]
    [string]$Command,
    [Parameter(Position=1, ValueFromRemainingArguments=$true)]
    [string[]]$Arguments
)

$ErrorActionPreference = "Stop"

$ContainerName = "uis-provision-host"
$Image = if ($env:UIS_IMAGE) { $env:UIS_IMAGE } else { "ghcr.io/terchris/uis-provision-host:latest" }
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

# Helper functions
function Write-Info { param($Message) Write-Host "[UIS] $Message" -ForegroundColor Green }
function Write-Warn { param($Message) Write-Host "[UIS] $Message" -ForegroundColor Yellow }
function Write-Err { param($Message) Write-Host "[UIS] $Message" -ForegroundColor Red }

# Get kubeconfig path
function Get-KubeConfigPath {
    return "$env:USERPROFILE\.kube\config"
}

# First-run initialization
function Initialize-FirstRun {
    $extendDir = Join-Path $ScriptDir ".uis.extend"
    $secretsDir = Join-Path $ScriptDir ".uis.secrets"

    if (-not (Test-Path $extendDir)) {
        Write-Info "First run - creating configuration folders..."
        New-Item -ItemType Directory -Path $extendDir -Force | Out-Null
        New-Item -ItemType Directory -Path $secretsDir -Force | Out-Null

        # Create .gitignore for secrets
        $gitignore = @"
# Never commit secrets
*
!.gitignore
!README.md
"@
        Set-Content -Path (Join-Path $secretsDir ".gitignore") -Value $gitignore

        Write-Info "Created .uis.extend\ and .uis.secrets\"
    }
}

# Check if container is running
function Test-ContainerRunning {
    $running = docker ps --format '{{.Names}}' 2>$null | Where-Object { $_ -eq $ContainerName }
    return $null -ne $running
}

# Check if image exists
function Test-ImageExists {
    try {
        docker image inspect $Image 2>$null | Out-Null
        return $true
    } catch {
        return $false
    }
}

# Pull image if needed
function Confirm-Image {
    if (Test-ImageExists) { return }

    if ($Image -match "/") {
        Write-Info "Image not found locally, pulling from registry..."
        docker pull $Image
        if ($LASTEXITCODE -ne 0) {
            Write-Err "Failed to pull image '$Image'"
            Write-Host ""
            Write-Host "Install UIS with:"
            Write-Host "  Invoke-WebRequest https://uis.sovereignsky.no/install.ps1 -OutFile install.ps1; .\install.ps1"
            exit 1
        }
        Write-Info "Image pulled successfully"
    } else {
        Write-Err "Image '$Image' not found!"
        exit 1
    }
}

# Start container
function Start-UISContainer {
    if (Test-ContainerRunning) {
        Write-Info "Container is already running"
        return
    }

    Initialize-FirstRun
    Confirm-Image

    Write-Info "Starting UIS container..."

    # Remove old container if exists
    docker rm -f $ContainerName 2>$null | Out-Null

    $kubeconfig = Get-KubeConfigPath
    $extendDir = Join-Path $ScriptDir ".uis.extend"
    $secretsDir = Join-Path $ScriptDir ".uis.secrets"

    # Convert Windows paths to Docker-compatible paths
    $extendMount = "${extendDir}:/mnt/urbalurbadisk/.uis.extend"
    $secretsMount = "${secretsDir}:/mnt/urbalurbadisk/.uis.secrets"

    # Build docker run command
    $dockerArgs = @(
        "run", "-d",
        "--name", $ContainerName,
        "--network", "host",
        "--privileged",
        "-v", $extendMount,
        "-v", $secretsMount
    )

    # Mount kubeconfig if it exists
    if (Test-Path $kubeconfig) {
        $kubeMount = "${kubeconfig}:/home/ansible/.kube/config:ro"
        $dockerArgs += "-v", $kubeMount
    } else {
        Write-Warn "Kubeconfig not found at $kubeconfig"
        Write-Info "Kubernetes commands will not work until kubeconfig is available"
    }

    $dockerArgs += $Image

    & docker @dockerArgs

    # Wait for container to be ready
    Start-Sleep -Seconds 2

    # Initialize config inside container
    try {
        docker exec $ContainerName bash -c `
            "source /mnt/urbalurbadisk/provision-host/uis/lib/first-run.sh && initialize_uis_config" 2>$null
    } catch { }

    Write-Info "Container started"
}

# Stop container
function Stop-UISContainer {
    if (Test-ContainerRunning) {
        Write-Info "Stopping UIS container..."
        docker stop $ContainerName | Out-Null
        docker rm $ContainerName 2>$null | Out-Null
        Write-Info "Container stopped"
    } else {
        Write-Warn "Container is not running"
    }
}

# Show status
function Show-Status {
    if (Test-ContainerRunning) {
        Write-Info "Container is running"
        docker ps --filter "name=$ContainerName" --format "table {{.Names}}`t{{.Status}}`t{{.Image}}"
    } else {
        Write-Warn "Container is not running"
        Write-Host ""
        Write-Host "Start with: .\uis.ps1 start"
    }
}

# Update container
function Update-UISContainer {
    Write-Info "Pulling latest UIS container image..."
    docker pull $Image
    if ($LASTEXITCODE -eq 0) {
        Write-Info "Image updated successfully"
        if (Test-ContainerRunning) {
            Write-Info "Restarting container with new image..."
            Stop-UISContainer
            Start-UISContainer
        }
    } else {
        Write-Err "Failed to pull image"
        exit 1
    }
}

# Execute UIS command
function Invoke-UISCommand {
    param([string[]]$Args)

    if (-not (Test-ContainerRunning)) {
        Write-Info "Container not running, starting..."
        Start-UISContainer
    }

    $allArgs = @($ContainerName, "/mnt/urbalurbadisk/provision-host/uis/manage/uis-cli.sh") + $Args
    docker exec -it @allArgs
}

# Show help
function Show-Help {
    Write-Host "UIS - Urbalurba Infrastructure Stack"
    Write-Host ""
    Write-Host "Usage: .\uis.ps1 <command> [args]"
    Write-Host ""
    Write-Host "Container Commands:"
    Write-Host "  start       Start the UIS container"
    Write-Host "  stop        Stop the UIS container"
    Write-Host "  restart     Restart the UIS container"
    Write-Host "  status      Show container status"
    Write-Host "  shell       Open a shell in the container"
    Write-Host "  logs        Show container logs"
    Write-Host "  update      Pull latest container image"
    Write-Host ""
    Write-Host "UIS Commands (after container is running):"
    Write-Host "  setup       Interactive configuration menu"
    Write-Host "  init        First-time configuration wizard"
    Write-Host "  list        List available services"
    Write-Host "  deploy      Deploy enabled services"
    Write-Host "  help        Show all UIS commands"
    Write-Host ""
    Write-Host "Examples:"
    Write-Host "  .\uis.ps1 start            # Start the container"
    Write-Host "  .\uis.ps1 deploy           # Deploy services"
    Write-Host "  .\uis.ps1 setup            # Interactive menu"
    Write-Host "  .\uis.ps1 shell            # Enter the container"
    Write-Host ""
    Write-Host "Quick start:"
    Write-Host "  .\uis.ps1 start; .\uis.ps1 deploy"
    Write-Host ""
    Write-Host "Documentation: https://uis.sovereignsky.no"
}

# Main command handler
switch ($Command) {
    "start" {
        Start-UISContainer
        Write-Info "UIS container is ready"
        Write-Host ""
        Write-Host "Next steps:"
        Write-Host "  .\uis.ps1 deploy       Deploy default services"
        Write-Host "  .\uis.ps1 setup        Interactive configuration"
        Write-Host "  .\uis.ps1 help         Show all commands"
    }
    "stop" {
        Stop-UISContainer
    }
    "restart" {
        Stop-UISContainer
        Start-UISContainer
        Write-Info "UIS container restarted"
    }
    "status" {
        Show-Status
    }
    "shell" {
        Start-UISContainer
        docker exec -it $ContainerName bash
    }
    "logs" {
        $tail = if ($Arguments.Count -gt 0) { $Arguments[0] } else { "50" }
        docker logs $ContainerName --tail $tail
    }
    "update" {
        Update-UISContainer
    }
    { $_ -eq "" -or $_ -eq $null } {
        Show-Help
    }
    default {
        # Route to uis-cli.sh
        $allArgs = @($Command) + $Arguments
        Invoke-UISCommand -Args $allArgs
    }
}
