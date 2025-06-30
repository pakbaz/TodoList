#!/usr/bin/env pwsh
# Docker Build Debug Script for TodoList
# This script provides extensive debugging and fallback options for Docker build issues

param(
    [switch]$Force,
    [switch]$CleanBuild,
    [switch]$Verbose,
    [int]$TimeoutMinutes = 10
)

Write-Host "=== TodoList Docker Build Debug Script ===" -ForegroundColor Cyan
Write-Host "Starting at: $(Get-Date)" -ForegroundColor Gray

# Function to run command with timeout
function Invoke-CommandWithTimeout {
    param(
        [string]$Command,
        [int]$TimeoutSeconds = 600,
        [string]$Description = "Command"
    )
    
    Write-Host "🔄 $Description..." -ForegroundColor Yellow
    Write-Host "Command: $Command" -ForegroundColor Gray
    
    $job = Start-Job -ScriptBlock { 
        param($cmd) 
        Invoke-Expression $cmd 
    } -ArgumentList $Command
    
    $completed = Wait-Job -Job $job -Timeout $TimeoutSeconds
    
    if ($completed) {
        Receive-Job -Job $job | Out-Host
        Remove-Job -Job $job
        Write-Host "✅ $Description completed successfully" -ForegroundColor Green
        return $true
    } else {
        Write-Host "❌ $Description timed out after $TimeoutSeconds seconds" -ForegroundColor Red
        Stop-Job -Job $job
        Remove-Job -Job $job
        return $false
    }
}

# Check Docker status
Write-Host "🐳 Checking Docker status..." -ForegroundColor Blue
try {
    $dockerVersion = docker --version
    Write-Host "Docker version: $dockerVersion" -ForegroundColor Green
    
    $dockerInfo = docker info --format "{{.ServerVersion}}"
    Write-Host "Docker server version: $dockerInfo" -ForegroundColor Green
} catch {
    Write-Host "❌ Docker is not available or not running" -ForegroundColor Red
    Write-Host "Please start Docker Desktop and try again" -ForegroundColor Yellow
    exit 1
}

# Clean up if requested
if ($CleanBuild) {
    Write-Host "🧹 Cleaning up Docker resources..." -ForegroundColor Blue
    
    # Remove existing containers
    $containers = docker ps -a --filter "name=todolist" -q
    if ($containers) {
        Write-Host "Removing existing containers..." -ForegroundColor Yellow
        docker rm -f $containers
    }
    
    # Remove existing images
    $images = docker images "todolist*" -q
    if ($images) {
        Write-Host "Removing existing images..." -ForegroundColor Yellow
        docker rmi -f $images
    }
    
    # Clean build cache
    Write-Host "Cleaning Docker build cache..." -ForegroundColor Yellow
    docker builder prune -f
}

# Set build arguments
$buildArgs = @()
if ($Verbose) {
    $buildArgs += "--progress=plain"
}
$buildArgs += "--no-cache"
$buildArgs += "-t", "todolist:debug"

# Build with different strategies
$strategies = @(
    @{
        Name = "Standard Build"
        Args = $buildArgs
        Description = "Normal Docker build process"
    },
    @{
        Name = "Build with Buildkit disabled"
        Args = $buildArgs
        Environment = @{ "DOCKER_BUILDKIT" = "0" }
        Description = "Fallback to legacy build system"
    },
    @{
        Name = "Build with specific platform"
        Args = $buildArgs + @("--platform", "linux/amd64")
        Description = "Force specific platform architecture"
    }
)

$buildSuccess = $false
$timeoutSeconds = $TimeoutMinutes * 60

foreach ($strategy in $strategies) {
    if ($buildSuccess) { break }
    
    Write-Host "`n🚀 Trying: $($strategy.Name)" -ForegroundColor Magenta
    Write-Host "$($strategy.Description)" -ForegroundColor Gray
    
    # Set environment variables if specified
    $originalEnv = @{}
    if ($strategy.Environment) {
        foreach ($key in $strategy.Environment.Keys) {
            $originalEnv[$key] = [Environment]::GetEnvironmentVariable($key)
            [Environment]::SetEnvironmentVariable($key, $strategy.Environment[$key])
            Write-Host "Set $key=$($strategy.Environment[$key])" -ForegroundColor Gray
        }
    }
    
    try {
        $buildCommand = "docker build $($strategy.Args -join ' ') ."
        Write-Host "Build command: $buildCommand" -ForegroundColor Gray
        
        $success = Invoke-CommandWithTimeout -Command $buildCommand -TimeoutSeconds $timeoutSeconds -Description $strategy.Name
        
        if ($success) {
            Write-Host "✅ Build succeeded with: $($strategy.Name)" -ForegroundColor Green
            $buildSuccess = $true
        } else {
            Write-Host "⏰ Build timed out with: $($strategy.Name)" -ForegroundColor Red
        }
    } catch {
        Write-Host "❌ Build failed with: $($strategy.Name)" -ForegroundColor Red
        Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
    } finally {
        # Restore environment variables
        foreach ($key in $originalEnv.Keys) {
            if ($originalEnv[$key]) {
                [Environment]::SetEnvironmentVariable($key, $originalEnv[$key])
            } else {
                [Environment]::SetEnvironmentVariable($key, $null)
            }
        }
    }
}

if (-not $buildSuccess) {
    Write-Host "`n❌ All build strategies failed!" -ForegroundColor Red
    Write-Host "🔍 Troubleshooting suggestions:" -ForegroundColor Yellow
    Write-Host "1. Check your internet connection" -ForegroundColor White
    Write-Host "2. Try restarting Docker Desktop" -ForegroundColor White
    Write-Host "3. Clear Docker cache: docker system prune -a" -ForegroundColor White
    Write-Host "4. Check Docker resources (CPU/Memory) in Docker Desktop settings" -ForegroundColor White
    Write-Host "5. Try building without cache: docker build --no-cache -t todolist:debug ." -ForegroundColor White
    Write-Host "6. Check for Windows Defender or antivirus interference" -ForegroundColor White
    
    # Show recent Docker logs
    Write-Host "`n📋 Recent Docker events:" -ForegroundColor Blue
    try {
        docker events --since=5m --until=now
    } catch {
        Write-Host "Could not retrieve Docker events" -ForegroundColor Yellow
    }
    
    exit 1
}

# Test the built image
Write-Host "`n🧪 Testing the built image..." -ForegroundColor Blue
try {
    # Quick test to see if image runs
    $testRun = Invoke-CommandWithTimeout -Command "docker run --rm -d --name todolist-test -p 8081:8080 todolist:debug" -TimeoutSeconds 30 -Description "Container startup test"
    
    if ($testRun) {
        Start-Sleep -Seconds 5
        
        # Test health endpoint
        try {
            $healthCheck = Invoke-RestMethod -Uri "http://localhost:8081/health" -TimeoutSec 10
            Write-Host "✅ Health check passed: $($healthCheck.status)" -ForegroundColor Green
        } catch {
            Write-Host "⚠️ Health check failed, but container started" -ForegroundColor Yellow
        }
        
        # Stop test container
        docker stop todolist-test 2>$null
        Write-Host "✅ Container test completed successfully" -ForegroundColor Green
    } else {
        Write-Host "❌ Container failed to start within timeout" -ForegroundColor Red
    }
} catch {
    Write-Host "❌ Container test failed: $($_.Exception.Message)" -ForegroundColor Red
}

# Show final image info
Write-Host "`n📊 Final image information:" -ForegroundColor Blue
try {
    docker images todolist:debug --format "table {{.Repository}}\t{{.Tag}}\t{{.Size}}\t{{.CreatedAt}}"
} catch {
    Write-Host "Could not retrieve image information" -ForegroundColor Yellow
}

Write-Host "`n🎉 Docker build debug script completed!" -ForegroundColor Green
Write-Host "Finished at: $(Get-Date)" -ForegroundColor Gray

# If successful, provide next steps
if ($buildSuccess) {
    Write-Host "`n📋 Next steps:" -ForegroundColor Blue
    Write-Host "1. Run the container: docker run -p 8080:8080 todolist:debug" -ForegroundColor White
    Write-Host "2. Test the application: http://localhost:8080" -ForegroundColor White
    Write-Host "3. Check health endpoint: http://localhost:8080/health" -ForegroundColor White
    Write-Host "4. View logs: docker logs <container_id>" -ForegroundColor White
}
