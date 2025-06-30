# PowerShell script to set up PostgreSQL database for TodoList application

Write-Host "Setting up PostgreSQL database for TodoList application..." -ForegroundColor Green

# Check if Docker is installed and running
try {
    $dockerVersion = docker --version
    Write-Host "Docker found: $dockerVersion" -ForegroundColor Green
} catch {
    Write-Host "Docker is not installed or not running. Please install Docker first." -ForegroundColor Red
    exit 1
}

# Stop and remove existing containers if they exist
Write-Host "Stopping existing containers..." -ForegroundColor Yellow
docker-compose down -v

# Start PostgreSQL using docker-compose
Write-Host "Starting PostgreSQL database..." -ForegroundColor Yellow
docker-compose up -d postgresql

# Wait for PostgreSQL to be ready
Write-Host "Waiting for PostgreSQL to be ready..." -ForegroundColor Yellow
$maxAttempts = 30
$attempt = 0

do {
    $attempt++
    try {
        $result = docker exec todolist-postgres pg_isready -U admin -d todolistdb
        if ($LASTEXITCODE -eq 0) {
            Write-Host "PostgreSQL is ready!" -ForegroundColor Green
            break
        }
    } catch {
        # Continue waiting
    }
    
    if ($attempt -ge $maxAttempts) {
        Write-Host "PostgreSQL failed to start within expected time" -ForegroundColor Red
        exit 1
    }
    
    Write-Host "Attempt $attempt/$maxAttempts - waiting..." -ForegroundColor Yellow
    Start-Sleep -Seconds 2
} while ($true)

# Test database connection
Write-Host "Testing database connection..." -ForegroundColor Yellow
try {
    $testResult = docker exec todolist-postgres psql -U admin -d todolistdb -c "SELECT 1;"
    Write-Host "Database connection successful!" -ForegroundColor Green
} catch {
    Write-Host "Database connection failed!" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "=== Setup Complete ===" -ForegroundColor Green
Write-Host "PostgreSQL is running on localhost:5432" -ForegroundColor White
Write-Host "Database: todolistdb" -ForegroundColor White
Write-Host "Username: admin" -ForegroundColor White
Write-Host "Password: password" -ForegroundColor White
Write-Host ""
Write-Host "Connection string:" -ForegroundColor White
Write-Host "Host=localhost;Database=todolistdb;Username=admin;Password=password" -ForegroundColor Cyan
Write-Host ""
Write-Host "To start the full application (including the app), run:" -ForegroundColor White
Write-Host "docker-compose up" -ForegroundColor Cyan
Write-Host ""
Write-Host "To run just the .NET app locally (with database in Docker):" -ForegroundColor White
Write-Host "dotnet run" -ForegroundColor Cyan
