#!/usr/bin/env pwsh
# Urbalurba API Project Setup Script

Write-Host "🔄 Setting up Urbalurba API project..." -ForegroundColor Green
Write-Host ""

# Check prerequisites
Write-Host "📋 Checking prerequisites..." -ForegroundColor Yellow

# Check if .NET is installed
try {
    $dotnetVersion = dotnet --version
    Write-Host "✅ .NET SDK version: $dotnetVersion" -ForegroundColor Green
} catch {
    Write-Host "❌ .NET SDK not found. Please install .NET 8 SDK first." -ForegroundColor Red
    Write-Host "   Download from: https://dotnet.microsoft.com/download" -ForegroundColor Yellow
    exit 1
}

# Check if Git is available
try {
    $gitVersion = git --version
    Write-Host "✅ Git is available: $gitVersion" -ForegroundColor Green
} catch {
    Write-Host "❌ Git not found. Please install Git first." -ForegroundColor Red
    exit 1
}

Write-Host ""

# Install NSwag globally if not present
Write-Host "🔧 Installing/updating NSwag..." -ForegroundColor Yellow
try {
    # Check if NSwag is already installed
    $nswagVersion = nswag version 2>$null
    if ($nswagVersion) {
        Write-Host "✅ NSwag is already installed: $nswagVersion" -ForegroundColor Green
    } else {
        throw "Not installed"
    }
} catch {
    Write-Host "📦 Installing NSwag globally..." -ForegroundColor Yellow
    dotnet tool install -g NSwag.ConsoleCore
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✅ NSwag installed successfully" -ForegroundColor Green
    } else {
        Write-Host "❌ Failed to install NSwag" -ForegroundColor Red
        exit 1
    }
}

Write-Host ""

# Initialize git submodule for shared schemas
Write-Host "📥 Setting up Urbalurba shared schemas..." -ForegroundColor Yellow

if (!(Test-Path "shared-schemas")) {
    Write-Host "   Initializing git submodule..." -ForegroundColor Gray
    git submodule add https://github.com/urbalurba/urbalurba-schemas.git shared-schemas
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✅ Shared schemas cloned successfully" -ForegroundColor Green
    } else {
        Write-Host "❌ Failed to clone shared schemas" -ForegroundColor Red
        Write-Host "   Make sure you have access to the Urbalurba schemas repository" -ForegroundColor Yellow
        exit 1
    }
} else {
    Write-Host "   Updating existing shared schemas..." -ForegroundColor Gray
    git submodule update --init --recursive
    git submodule update --remote
    Write-Host "✅ Shared schemas updated" -ForegroundColor Green
}

Write-Host ""

# Create basic directory structure if it doesn't exist
Write-Host "📁 Creating project structure..." -ForegroundColor Yellow

$directories = @(
    "api/server/src/Controllers",
    "api/client/generated",
    "tests",
    "docs"
)

foreach ($dir in $directories) {
    if (!(Test-Path $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
        Write-Host "   Created: $dir" -ForegroundColor Gray
    }
}

Write-Host "✅ Project structure ready" -ForegroundColor Green
Write-Host ""

# Validate the template API specification
Write-Host "🔍 Validating template API specification..." -ForegroundColor Yellow
try {
    nswag validate /input:api/specs/my-api-v1.yaml
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✅ Template API specification is valid" -ForegroundColor Green
    } else {
        throw "Validation failed"
    }
} catch {
    Write-Host "❌ Template API specification validation failed" -ForegroundColor Red
    Write-Host "   This might indicate an issue with the template" -ForegroundColor Yellow
    exit 1
}

Write-Host ""

# Create .gitignore if it doesn't exist
if (!(Test-Path ".gitignore")) {
    Write-Host "📝 Creating .gitignore..." -ForegroundColor Yellow
    @"
# Generated code (will be regenerated)
api/server/src/Controllers/GeneratedControllers.cs
api/client/generated/

# .NET
bin/
obj/
*.user
*.suo
.vs/

# Logs
*.log

# OS
.DS_Store
Thumbs.db
"@ | Out-File -FilePath ".gitignore" -Encoding UTF8
    Write-Host "✅ .gitignore created" -ForegroundColor Green
}

Write-Host ""
Write-Host "🎉 Setup complete!" -ForegroundColor Green
Write-Host ""
Write-Host "📖 Next steps:" -ForegroundColor Yellow
Write-Host "   1. Edit your API specification: api/specs/my-api-v1.yaml" -ForegroundColor White
Write-Host "   2. Look at examples: shared-schemas/examples/how-to-reference.yaml" -ForegroundColor White
Write-Host "   3. Validate your changes: ./tools/validate.ps1" -ForegroundColor White
Write-Host "   4. Generate code: ./tools/generate.ps1" -ForegroundColor White
Write-Host ""
Write-Host "🆘 Need help? Check docs/GETTING-STARTED.md or contact api-team@urbalurba.no" -ForegroundColor Cyan
Write-Host ""
