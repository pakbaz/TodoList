#!/usr/bin/env pwsh
# Simple Docker Build Test for TodoList
# This script tests Docker build with timeout and fallback strategies

Write-Host "=== TodoList Docker Build Test ===" -ForegroundColor Cyan

# Check Docker
Write-Host "🐳 Checking Docker..." -ForegroundColor Blue
try {
    docker --version | Out-Host
    if ($LASTEXITCODE -ne 0) { throw "Docker command failed" }
} catch {
    Write-Host "❌ Docker is not available" -ForegroundColor Red
    exit 1
}

# Clean up previous attempts
Write-Host "🧹 Cleaning up..." -ForegroundColor Blue
docker ps -a --filter "name=todolist" -q | ForEach-Object { docker rm -f $_ } | Out-Null
docker images "todolist*" -q | ForEach-Object { docker rmi -f $_ } | Out-Null

# Strategy 1: Standard build with timeout
Write-Host "🚀 Strategy 1: Standard build (5 min timeout)..." -ForegroundColor Magenta

$job1 = Start-Job -ScriptBlock {
    Set-Location $args[0]
    docker build --no-cache -t todolist:test .
} -ArgumentList (Get-Location)

$completed1 = Wait-Job -Job $job1 -Timeout 300
if ($completed1) {
    Receive-Job -Job $job1 | Out-Host
    Remove-Job -Job $job1
    Write-Host "✅ Standard build succeeded!" -ForegroundColor Green
    
    # Quick test
    Write-Host "🧪 Quick container test..." -ForegroundColor Blue
    $containerId = docker run -d -p 8082:8080 todolist:test
    Start-Sleep -Seconds 3
    docker stop $containerId | Out-Null
    docker rm $containerId | Out-Null
    Write-Host "✅ Container test passed!" -ForegroundColor Green
    exit 0
} else {
    Write-Host "⏰ Standard build timed out" -ForegroundColor Yellow
    Stop-Job -Job $job1
    Remove-Job -Job $job1
}

# Strategy 2: Build without BuildKit
Write-Host "🚀 Strategy 2: Build without BuildKit..." -ForegroundColor Magenta
$env:DOCKER_BUILDKIT = "0"

$job2 = Start-Job -ScriptBlock {
    Set-Location $args[0]
    $env:DOCKER_BUILDKIT = "0"
    docker build --no-cache -t todolist:test-legacy .
} -ArgumentList (Get-Location)

$completed2 = Wait-Job -Job $job2 -Timeout 300
if ($completed2) {
    Receive-Job -Job $job2 | Out-Host
    Remove-Job -Job $job2
    Write-Host "✅ Legacy build succeeded!" -ForegroundColor Green
    exit 0
} else {
    Write-Host "⏰ Legacy build timed out" -ForegroundColor Yellow
    Stop-Job -Job $job2
    Remove-Job -Job $job2
}

# Strategy 3: Manual restore test
Write-Host "🚀 Strategy 3: Testing manual restore..." -ForegroundColor Magenta
Write-Host "Testing dotnet restore directly..." -ForegroundColor Gray

try {
    $restoreOutput = dotnet restore --verbosity normal 2>&1
    Write-Host $restoreOutput -ForegroundColor Gray
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✅ Local dotnet restore works fine" -ForegroundColor Green
        Write-Host "Issue might be Docker-specific or network-related" -ForegroundColor Yellow
    } else {
        Write-Host "❌ Local dotnet restore failed" -ForegroundColor Red
        Write-Host "Issue is with the project itself" -ForegroundColor Yellow
    }
} catch {
    Write-Host "❌ Could not test dotnet restore: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host "`n❌ All Docker build strategies failed!" -ForegroundColor Red
Write-Host "🔍 Recommendations:" -ForegroundColor Yellow
Write-Host "1. Restart Docker Desktop" -ForegroundColor White
Write-Host "2. Check network connectivity" -ForegroundColor White
Write-Host "3. Try: docker system prune -a" -ForegroundColor White
Write-Host "4. Increase Docker memory limits" -ForegroundColor White
Write-Host "5. Try building on a different network" -ForegroundColor White

exit 1
