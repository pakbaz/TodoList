# Clear Docker Build Cache Script
# This script clears all build artifacts and caches to fix Docker build issues with azd up

Write-Host "🧹 Clearing all build artifacts and caches..." -ForegroundColor Yellow

# 1. Clean .NET build artifacts
Write-Host "Cleaning .NET build artifacts..." -ForegroundColor Cyan
dotnet clean

# 2. Remove obj and bin directories
Write-Host "Removing obj/ and bin/ directories..." -ForegroundColor Cyan
Remove-Item -Recurse -Force obj, bin -ErrorAction SilentlyContinue

# 3. Clear NuGet caches
Write-Host "Clearing NuGet caches..." -ForegroundColor Cyan
dotnet nuget locals all --clear

# 4. Clear Docker system cache
Write-Host "Clearing Docker system cache..." -ForegroundColor Cyan
docker system prune -a --volumes -f

# 5. Remove AZD cache
Write-Host "Removing AZD cache..." -ForegroundColor Cyan
Remove-Item -Recurse -Force .azd -ErrorAction SilentlyContinue

Write-Host "✅ Cache cleanup complete! You can now try 'azd up' again." -ForegroundColor Green
Write-Host "   If the issue persists, check the troubleshooting scripts in the scripts/ folder." -ForegroundColor Gray
