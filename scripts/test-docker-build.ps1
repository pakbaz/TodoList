# Local Docker build test script for TodoList (PowerShell)
# This script helps debug Docker build issues before deploying via GitHub Actions

$ErrorActionPreference = "Stop"

Write-Host "🐳 Testing Docker build locally..." -ForegroundColor Blue

# Clean up any existing containers
Write-Host "🧹 Cleaning up existing containers..." -ForegroundColor Yellow
try {
    docker stop todolist-test 2>$null
    docker rm todolist-test 2>$null
} catch {
    # Ignore errors if containers don't exist
}

# Build the image
Write-Host "🔨 Building Docker image..." -ForegroundColor Yellow
$env:DOCKER_BUILDKIT = 1
docker build --progress=plain --no-cache -t todolist-app:test .

if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Docker build failed!" -ForegroundColor Red
    exit 1
}

# Test the image
Write-Host "🧪 Testing the built image..." -ForegroundColor Yellow
docker run -d `
  --name todolist-test `
  -p 8080:8080 `
  -e ASPNETCORE_ENVIRONMENT=Development `
  -e "ConnectionStrings__SqliteConnection=Data Source=:memory:" `
  todolist-app:test

if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Failed to start container!" -ForegroundColor Red
    exit 1
}

# Wait for the app to start
Write-Host "⏳ Waiting for application to start..." -ForegroundColor Yellow
Start-Sleep -Seconds 10

# Test health endpoint
Write-Host "🔍 Testing health endpoint..." -ForegroundColor Yellow
try {
    $response = Invoke-WebRequest -Uri "http://localhost:8080/health" -UseBasicParsing
    if ($response.StatusCode -eq 200) {
        Write-Host "✅ Application is healthy!" -ForegroundColor Green
    } else {
        throw "Health check returned status code: $($response.StatusCode)"
    }
} catch {
    Write-Host "❌ Application health check failed: $_" -ForegroundColor Red
    Write-Host "Container logs:" -ForegroundColor Yellow
    docker logs todolist-test
    docker stop todolist-test 2>$null
    docker rm todolist-test 2>$null
    exit 1
}

# Test API endpoint
Write-Host "🔍 Testing API endpoint..." -ForegroundColor Yellow
try {
    $response = Invoke-WebRequest -Uri "http://localhost:8080/mcp/todos" -UseBasicParsing
    if ($response.StatusCode -eq 200) {
        Write-Host "✅ API endpoint is working!" -ForegroundColor Green
    } else {
        throw "API test returned status code: $($response.StatusCode)"
    }
} catch {
    Write-Host "❌ API endpoint test failed: $_" -ForegroundColor Red
    Write-Host "Container logs:" -ForegroundColor Yellow
    docker logs todolist-test
    docker stop todolist-test 2>$null
    docker rm todolist-test 2>$null
    exit 1
}

# Clean up
Write-Host "🧹 Cleaning up test container..." -ForegroundColor Yellow
docker stop todolist-test
docker rm todolist-test

Write-Host "✅ Docker build test completed successfully!" -ForegroundColor Green
Write-Host "🚀 You can now push to GitHub to trigger the deployment workflow." -ForegroundColor Green
