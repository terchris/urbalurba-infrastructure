# UIS - Urbalurba Infrastructure Stack CLI wrapper (PowerShell)
# This script manages the UIS provision-host container
#
# Usage: .\uis.ps1 <command> [args]
# Run .\uis.ps1 help for available commands

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ContainerName = "uis-provision-host"
$Image = if ($env:UIS_IMAGE) { $env:UIS_IMAGE } else { "ghcr.io/terchris/uis-provision-host:latest" }
$KubeconfigDir = if ($env:UIS_KUBECONFIG_DIR) { $env:UIS_KUBECONFIG_DIR } else { Join-Path $HOME ".kube" }

# Detect if we have an interactive terminal
$DockerIT = if ([Environment]::UserInteractive -and -not [Console]::IsInputRedirected) { "-it" } else { "" }

function Log-Info { param([string]$Message) Write-Host "[UIS] $Message" -ForegroundColor Green }
function Log-Warn { param([string]$Message) Write-Host "[UIS] $Message" -ForegroundColor Yellow }
function Log-Error { param([string]$Message) Write-Host "[UIS] $Message" -ForegroundColor Red }

function Check-Image {
    $null = docker image inspect $Image 2>&1
    if ($LASTEXITCODE -eq 0) { return }

    if ($Image -match "/") {
        Log-Info "Image '$Image' not found locally, pulling from registry..."
        docker pull $Image
        if ($LASTEXITCODE -eq 0) {
            Log-Info "Image pulled successfully"
            return
        }
        Log-Error "Failed to pull image '$Image'"
    } else {
        Log-Error "Image '$Image' not found!"
    }

    Log-Info "Build it with: docker build -f Dockerfile.uis-provision-host -t uis-provision-host:local ."
    Log-Info "Or pull from registry: `$env:UIS_IMAGE = 'ghcr.io/terchris/uis-provision-host:latest'"
    exit 1
}

function Init-ConfigDirs {
    $firstRun = $false

    $extendDir = Join-Path $ScriptDir ".uis.extend"
    if (-not (Test-Path $extendDir)) {
        Log-Info "Creating .uis.extend/ configuration directory..."
        New-Item -ItemType Directory -Path $extendDir -Force | Out-Null
        $firstRun = $true
    }

    $secretsDir = Join-Path $ScriptDir ".uis.secrets"
    if (-not (Test-Path $secretsDir)) {
        Log-Info "Creating .uis.secrets/ directory..."
        New-Item -ItemType Directory -Path $secretsDir -Force | Out-Null
        $firstRun = $true
    }

    $gitignore = Join-Path $ScriptDir ".gitignore"
    if (-not (Test-Path $gitignore)) {
        @("# UIS secrets - do not commit", ".uis.secrets/") | Set-Content $gitignore
        Log-Info "Created .gitignore with .uis.secrets/"
    } elseif (-not (Select-String -Path $gitignore -Pattern "^\.uis\.secrets" -Quiet)) {
        @("", "# UIS secrets (auto-added)", ".uis.secrets/") | Add-Content $gitignore
        Log-Info "Added .uis.secrets/ to .gitignore"
    }

    return $firstRun
}

function Show-Welcome {
    docker exec $ContainerName bash -c 'if [ -f /mnt/urbalurbadisk/provision-host/uis/templates/welcome.txt ]; then cat /mnt/urbalurbadisk/provision-host/uis/templates/welcome.txt; fi' 2>$null
}

function Start-UISContainer {
    $running = docker ps --format '{{.Names}}' 2>$null | Where-Object { $_ -eq $ContainerName }
    if ($running) { return }

    Check-Image
    $firstRun = Init-ConfigDirs

    Log-Info "Starting UIS container..."

    docker rm -f $ContainerName 2>$null | Out-Null

    $volumeArgs = @(
        "-v", "${ScriptDir}/.uis.extend:/mnt/urbalurbadisk/.uis.extend"
        "-v", "${ScriptDir}/.uis.secrets:/mnt/urbalurbadisk/.uis.secrets"
    )

    if (Test-Path $KubeconfigDir) {
        $volumeArgs += "-v", "${KubeconfigDir}:/home/ansible/.kube:ro"
    } else {
        Log-Warn "Kubeconfig directory not found: $KubeconfigDir"
        Log-Warn "Kubernetes commands will not work until kubeconfig is configured"
    }

    docker run -d --name $ContainerName --network host --privileged @volumeArgs $Image
    if ($LASTEXITCODE -ne 0) {
        Log-Error "Failed to start container"
        exit 1
    }

    Start-Sleep -Seconds 2

    docker exec $ContainerName bash -c 'if [ -d /mnt/urbalurbadisk/.uis.secrets ]; then mkdir -p /mnt/urbalurbadisk/.uis.secrets/generated/kubeconfig; ln -sf /home/ansible/.kube/config /mnt/urbalurbadisk/.uis.secrets/generated/kubeconfig/kubeconf-all; fi' 2>$null

    Log-Info "Container started"

    if ($firstRun) {
        docker exec $ContainerName /mnt/urbalurbadisk/provision-host/uis/manage/uis-cli.sh init 2>$null
        Show-Welcome
    }
}

function Pull-UISContainer {
    Log-Info "Pulling latest UIS container image..."
    docker pull $Image
    if ($LASTEXITCODE -ne 0) {
        Log-Error "Failed to pull image"
        exit 1
    }
    Log-Info "Image updated successfully"
    $running = docker ps --format '{{.Names}}' 2>$null | Where-Object { $_ -eq $ContainerName }
    if ($running) {
        Log-Info "Restarting container with new image..."
        Stop-UISContainer
        Start-UISContainer
        Log-Info "Container restarted with new image"
    } else {
        Log-Info "Container is not running. Start it with: .\uis.ps1 start"
    }
}

function Stop-UISContainer {
    $running = docker ps --format '{{.Names}}' 2>$null | Where-Object { $_ -eq $ContainerName }
    if ($running) {
        Log-Info "Stopping UIS container..."
        docker stop $ContainerName | Out-Null
        Log-Info "Container stopped"
    } else {
        Log-Warn "Container is not running"
    }
}

# Main command handler
$command = if ($args.Count -gt 0) { $args[0] } else { "help" }
$remaining = if ($args.Count -gt 1) { $args[1..($args.Count - 1)] } else { @() }

switch ($command) {
    "start" {
        Start-UISContainer
        Log-Info "UIS container is ready"
    }
    "stop" {
        Stop-UISContainer
    }
    "restart" {
        Stop-UISContainer
        Start-UISContainer
        Log-Info "UIS container restarted"
    }
    "container" {
        $running = docker ps --format '{{.Names}}' 2>$null | Where-Object { $_ -eq $ContainerName }
        if ($running) {
            Log-Info "Container is running"
            docker ps --filter "name=$ContainerName" --format "table {{.Names}}`t{{.Status}}`t{{.Ports}}"
        } else {
            Log-Warn "Container is not running"
        }
    }
    "shell" {
        Start-UISContainer
        docker exec -it $ContainerName bash
    }
    "provision" {
        Start-UISContainer
        Log-Info "Running kubernetes provisioning..."
        docker exec -it $ContainerName bash -c "cd /mnt/urbalurbadisk/provision-host/kubernetes && ./provision-kubernetes.sh rancher-desktop"
    }
    "exec" {
        if ($remaining.Count -eq 0) {
            Log-Error "No command specified"
            exit 1
        }
        Start-UISContainer
        docker exec $DockerIT $ContainerName @remaining
    }
    "logs" {
        $tail = if ($remaining.Count -gt 0) { $remaining[0] } else { "--tail 50" }
        docker logs $ContainerName $tail
    }
    "pull" {
        Pull-UISContainer
    }
    "build" {
        Log-Info "Building UIS container image..."
        docker build -f (Join-Path $ScriptDir "Dockerfile.uis-provision-host") -t uis-provision-host:local $ScriptDir
        Log-Info "Build complete"
    }
    "test" {
        Log-Info "Running UIS container validation tests..."
        Start-UISContainer

        docker exec $ContainerName rm -rf /mnt/urbalurbadisk/.temp /mnt/urbalurbadisk/generate 2>$null

        Log-Info "Test 1: uis-cli version"
        docker exec $ContainerName /mnt/urbalurbadisk/provision-host/uis/manage/uis-cli.sh version

        Log-Info "Test 2: uis-cli list"
        docker exec $ContainerName /mnt/urbalurbadisk/provision-host/uis/manage/uis-cli.sh list

        Log-Info "Test 3: uis-cli stack list"
        docker exec $ContainerName /mnt/urbalurbadisk/provision-host/uis/manage/uis-cli.sh stack list

        Log-Info "Test 4: JSON generation"
        docker exec $ContainerName bash -c "cd /mnt/urbalurbadisk && ./provision-host/uis/manage/uis-docs.sh"

        Log-Info "Test 5: Schema validation"
        docker exec $ContainerName bash -c "cd /mnt/urbalurbadisk && ./provision-host/uis/tests/validate-schemas.sh"

        Log-Info "Test 6: Enable/disable service"
        docker exec $ContainerName /mnt/urbalurbadisk/provision-host/uis/manage/uis-cli.sh enable prometheus
        docker exec $ContainerName /mnt/urbalurbadisk/provision-host/uis/manage/uis-cli.sh list-enabled
        docker exec $ContainerName /mnt/urbalurbadisk/provision-host/uis/manage/uis-cli.sh disable prometheus

        Log-Info "All tests passed!"
    }
    { $_ -in "help", "--help", "-h" } {
        Start-UISContainer
        docker exec $DockerIT $ContainerName /mnt/urbalurbadisk/provision-host/uis/manage/uis-cli.sh help
        Write-Host ""
        Write-Host "Container management:"
        Write-Host "  start       Start the UIS container"
        Write-Host "  stop        Stop the UIS container"
        Write-Host "  restart     Restart the UIS container"
        Write-Host "  container   Show container status"
        Write-Host "  shell       Open a shell in the container"
        Write-Host "  logs        Show container logs"
        Write-Host "  pull        Pull latest container image and restart"
        Write-Host "  build       Build the container image locally"
        Write-Host "  test        Run container validation tests"
    }
    default {
        Start-UISContainer
        docker exec $DockerIT $ContainerName /mnt/urbalurbadisk/provision-host/uis/manage/uis-cli.sh @args
    }
}
