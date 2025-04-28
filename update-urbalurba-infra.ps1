# Define the URL and temporary file path
$url = "https://github.com/norwegianredcross/urbalurba-infrastructure/releases/download/latest/urbalurba-infrastructure.zip"
$tempZipPath = Join-Path $env:TEMP "urbalurba-infrastructure.zip"
$currentLocation = Get-Location

try {
    # Download the zip file
    Write-Host "Downloading Urbalurba Infrastructure from $url..."
    Invoke-WebRequest -Uri $url -OutFile $tempZipPath

    # Create a temporary extraction directory
    $tempExtractPath = Join-Path $env:TEMP "urbalurba-infrastructure"
    if (Test-Path $tempExtractPath) {
        Remove-Item $tempExtractPath -Recurse -Force
    }
    New-Item -ItemType Directory -Path $tempExtractPath | Out-Null

    # Extract the zip file to temporary location
    Write-Host "Extracting Urbalurba Infrastructure..."
    Expand-Archive -Path $tempZipPath -DestinationPath $tempExtractPath

    # Copy all contents to current directory
    Write-Host "Installing Urbalurba Infrastructure..."
    Get-ChildItem -Path $tempExtractPath | Copy-Item -Destination $currentLocation -Recurse -Force

    Write-Host "Urbalurba Infrastructure installation completed successfully!"
}
catch {
    Write-Error "An error occurred: $_"
}
finally {
    # Cleanup
    if (Test-Path $tempZipPath) {
        Remove-Item $tempZipPath -Force
    }
    if (Test-Path $tempExtractPath) {
        Remove-Item $tempExtractPath -Recurse -Force
    }
} 