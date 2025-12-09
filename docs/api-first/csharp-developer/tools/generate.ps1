#!/usr/bin/env pwsh
# Red Cross API Code Generation Script

Write-Host "🏗️ Generating server and client code from your API specification..." -ForegroundColor Green
Write-Host ""

# Ensure schemas are up to date
Write-Host "🔄 Updating shared schemas..." -ForegroundColor Yellow
try {
    git submodule update --remote --quiet
    Write-Host "✅ Shared schemas updated" -ForegroundColor Green
} catch {
    Write-Host "⚠️  Could not update shared schemas (continuing anyway)" -ForegroundColor Yellow
}

Write-Host ""

# Validate before generating
Write-Host "🔍 Pre-generation validation..." -ForegroundColor Yellow
try {
    nswag validate /input:api/specs/my-api-v1.yaml
    if ($LASTEXITCODE -ne 0) {
        Write-Host "❌ API specification is invalid. Please fix errors before generating code." -ForegroundColor Red
        Write-Host "   Run ./tools/validate.ps1 for detailed error information" -ForegroundColor Yellow
        exit 1
    }
    Write-Host "✅ API specification is valid" -ForegroundColor Green
} catch {
    Write-Host "❌ Validation failed. Cannot generate code." -ForegroundColor Red
    exit 1
}

Write-Host ""

# Generate server code
Write-Host "🖥️ Generating server code..." -ForegroundColor Yellow
try {
    Push-Location "api/server"
    
    # Ensure output directory exists
    if (!(Test-Path "src/Controllers")) {
        New-Item -ItemType Directory -Path "src/Controllers" -Force | Out-Null
    }
    
    Write-Host "   Running NSwag server generation..." -ForegroundColor Gray
    nswag run nswag-server.json
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✅ Server code generated successfully" -ForegroundColor Green
        
        # Check if file was created
        if (Test-Path "src/Controllers/GeneratedControllers.cs") {
            $fileSize = (Get-Item "src/Controllers/GeneratedControllers.cs").Length
            Write-Host "   Generated: src/Controllers/GeneratedControllers.cs ($fileSize bytes)" -ForegroundColor Gray
        }
    } else {
        throw "Server generation failed"
    }
    
} catch {
    Write-Host "❌ Failed to generate server code" -ForegroundColor Red
    Write-Host "   Error: $($_.Exception.Message)" -ForegroundColor Yellow
    exit 1
} finally {
    Pop-Location
}

Write-Host ""

# Generate client code
Write-Host "📱 Generating client code..." -ForegroundColor Yellow
try {
    Push-Location "api/client"
    
    # Ensure output directory exists
    if (!(Test-Path "generated")) {
        New-Item -ItemType Directory -Path "generated" -Force | Out-Null
    }
    
    Write-Host "   Running NSwag client generation..." -ForegroundColor Gray
    nswag run nswag-client.json
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✅ Client code generated successfully" -ForegroundColor Green
        
        # Check if file was created
        if (Test-Path "generated/MyProjectApiClient.cs") {
            $fileSize = (Get-Item "generated/MyProjectApiClient.cs").Length
            Write-Host "   Generated: generated/MyProjectApiClient.cs ($fileSize bytes)" -ForegroundColor Gray
        }
    } else {
        throw "Client generation failed"
    }
    
} catch {
    Write-Host "❌ Failed to generate client code" -ForegroundColor Red
    Write-Host "   Error: $($_.Exception.Message)" -ForegroundColor Yellow
    exit 1
} finally {
    Pop-Location
}

Write-Host ""

# Summary
Write-Host "🎉 Code generation complete!" -ForegroundColor Green
Write-Host ""
Write-Host "📁 Generated files:" -ForegroundColor Cyan
Write-Host "   🖥️  Server: api/server/src/Controllers/GeneratedControllers.cs" -ForegroundColor White
Write-Host "   📱 Client: api/client/generated/MyProjectApiClient.cs" -ForegroundColor White
Write-Host ""
Write-Host "🚀 Next steps:" -ForegroundColor Yellow
Write-Host "   1. Implement business logic in the generated controller methods" -ForegroundColor White
Write-Host "   2. The generated methods throw NotImplementedException() - replace with your code" -ForegroundColor White
Write-Host "   3. Use partial classes to keep your implementation separate from generated code" -ForegroundColor White
Write-Host "   4. Test your implementation: ./tools/test.ps1" -ForegroundColor White
Write-Host ""
Write-Host "💡 Pro tips:" -ForegroundColor Cyan
Write-Host "   • Don't edit the generated files directly - they'll be overwritten" -ForegroundColor White
Write-Host "   • Create implementation files like MyController.Implementation.cs" -ForegroundColor White
Write-Host "   • Use dependency injection for your services" -ForegroundColor White
Write-Host "   • The client can be used for testing your API" -ForegroundColor White
Write-Host ""
Write-Host "📖 Need help implementing? Check docs/EXAMPLES.md" -ForegroundColor Yellow
Write-Host ""
