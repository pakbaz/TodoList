# Test script for MCP server functionality
Write-Host "Testing MCP Server endpoints..." -ForegroundColor Green

# Test basic health check
try {
    $healthResponse = Invoke-RestMethod -Uri "http://localhost:8080/health" -Method Get
    Write-Host "✓ Health check: $($healthResponse.status)" -ForegroundColor Green
} catch {
    Write-Host "✗ Health check failed: $($_.Exception.Message)" -ForegroundColor Red
}

# Test MCP todos endpoint
try {
    $todosResponse = Invoke-RestMethod -Uri "http://localhost:8080/mcp/todos" -Method Get
    Write-Host "✓ MCP Todos endpoint: Found $($todosResponse.count) todos" -ForegroundColor Green
} catch {
    Write-Host "✗ MCP Todos endpoint failed: $($_.Exception.Message)" -ForegroundColor Red
}

# Test MCP protocol endpoint
try {
    $mcpRequest = @{
        jsonrpc = "2.0"
        id = 1
        method = "initialize"
        params = @{}
    } | ConvertTo-Json -Depth 3

    $mcpResponse = Invoke-RestMethod -Uri "http://localhost:8080/mcp" -Method Post -Body $mcpRequest -ContentType "application/json"
    Write-Host "✓ MCP Protocol endpoint: Server $($mcpResponse.result.serverInfo.name)" -ForegroundColor Green
} catch {
    Write-Host "✗ MCP Protocol endpoint failed: $($_.Exception.Message)" -ForegroundColor Red
}
