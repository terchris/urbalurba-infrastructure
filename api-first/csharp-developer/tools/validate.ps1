#!/usr/bin/env pwsh
# Urbalurba API Validation Script

Write-Host "🔍 Validating your Urbalurba API specification..." -ForegroundColor Green
Write-Host ""

# Update shared schemas to latest version
Write-Host "🔄 Updating shared schemas..." -ForegroundColor Yellow
try {
    git submodule update --remote --quiet
    Write-Host "✅ Shared schemas updated" -ForegroundColor Green
} catch {
    Write-Host "⚠️  Could not update shared schemas (continuing anyway)" -ForegroundColor Yellow
}

Write-Host ""

# Check if API specification exists
$apiSpecFile = "api/specs/my-api-v1.yaml"
if (!(Test-Path $apiSpecFile)) {
    Write-Host "❌ API specification not found: $apiSpecFile" -ForegroundColor Red
    Write-Host "   Make sure you're running this from the project root directory" -ForegroundColor Yellow
    exit 1
}

# Validate the API specification
Write-Host "🔍 Validating API specification..." -ForegroundColor Yellow
Write-Host "   File: $apiSpecFile" -ForegroundColor Gray

try {
    $output = nswag validate /input:$apiSpecFile 2>&1
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✅ API specification is valid!" -ForegroundColor Green
        Write-Host ""
        Write-Host "📊 Quick summary:" -ForegroundColor Cyan
        
        # Try to extract some basic info from the spec
        try {
            $content = Get-Content $apiSpecFile -Raw | ConvertFrom-Yaml
            $title = $content.info.title
            $version = $content.info.version
            $pathCount = ($content.paths | Get-Member -MemberType NoteProperty).Count
            
            Write-Host "   Title: $title" -ForegroundColor White
            Write-Host "   Version: $version" -ForegroundColor White
            Write-Host "   Endpoints: $pathCount" -ForegroundColor White
        } catch {
            # If YAML parsing fails, just show success
            Write-Host "   Your API specification passed all validation checks" -ForegroundColor White
        }
        
        Write-Host ""
        Write-Host "🚀 Ready for next step: ./tools/generate.ps1" -ForegroundColor Green
        
    } else {
        Write-Host "❌ API specification has validation errors:" -ForegroundColor Red
        Write-Host ""
        Write-Host $output -ForegroundColor Yellow
        Write-Host ""
        Write-Host "🛠️  Common fixes:" -ForegroundColor Cyan
        Write-Host "   • Check YAML syntax (indentation, colons, quotes)" -ForegroundColor White
        Write-Host "   • Verify all `$ref` paths point to existing files" -ForegroundColor White
        Write-Host "   • Ensure required fields are present in schemas" -ForegroundColor White
        Write-Host "   • Check examples match schema definitions" -ForegroundColor White
        Write-Host ""
        Write-Host "📖 Need help? Check shared-schemas/examples/how-to-reference.yaml" -ForegroundColor Yellow
        exit 1
    }
    
} catch {
    Write-Host "❌ Validation failed with error:" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Yellow
    Write-Host ""
    Write-Host "🔧 Possible issues:" -ForegroundColor Cyan
    Write-Host "   • NSwag is not installed (run ./tools/setup.ps1)" -ForegroundColor White
    Write-Host "   • File path is incorrect" -ForegroundColor White
    Write-Host "   • YAML file is corrupted" -ForegroundColor White
    exit 1
}

# Check for common anti-patterns
Write-Host ""
Write-Host "🕵️  Checking for common issues..." -ForegroundColor Yellow

$specContent = Get-Content $apiSpecFile -Raw

# Check if using shared schemas
if ($specContent -match '\$ref.*shared-schemas') {
    Write-Host "✅ Using shared Urbalurba schemas - good!" -ForegroundColor Green
} else {
    Write-Host "⚠️  No shared schema references found" -ForegroundColor Yellow
    Write-Host "   Consider using shared schemas from shared-schemas/ folder" -ForegroundColor Gray
}

# Check for TODO markers
$todoCount = ($specContent | Select-String -Pattern "TODO" -AllMatches).Matches.Count
if ($todoCount -gt 0) {
    Write-Host "📝 Found $todoCount TODO items to complete" -ForegroundColor Yellow
}

# Check for example values
if ($specContent -match 'example:') {
    Write-Host "✅ Found example values - helps with documentation" -ForegroundColor Green
} else {
    Write-Host "💡 Consider adding example values to your schemas" -ForegroundColor Cyan
}

Write-Host ""
Write-Host "🎯 Validation complete! Your API specification is ready." -ForegroundColor Green
Write-Host ""
