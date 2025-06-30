#!/usr/bin/env pwsh

# Test MCP endpoint connectivity
$baseUrl = "http://localhost:5155"

Write-Host "Testing TodoList MCP Server Endpoints..." -ForegroundColor Green
Write-Host "Base URL: $baseUrl" -ForegroundColor Yellow

# Test 1: Health endpoint
Write-Host "`n1. Testing Health Endpoint..." -ForegroundColor Cyan
try {
    $healthResponse = Invoke-RestMethod -Uri "$baseUrl/health" -Method GET -ContentType "application/json"
    Write-Host "✅ Health endpoint working: $($healthResponse | ConvertTo-Json -Depth 2)" -ForegroundColor Green
} catch {
    Write-Host "❌ Health endpoint failed: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Make sure the application is running on port 5155" -ForegroundColor Yellow
    exit 1
}

# Test 2: Get todos endpoint
Write-Host "`n2. Testing Get Todos Endpoint..." -ForegroundColor Cyan
try {
    $todosResponse = Invoke-RestMethod -Uri "$baseUrl/mcp/todos" -Method GET -ContentType "application/json"
    Write-Host "✅ Get todos endpoint working: $($todosResponse | ConvertTo-Json -Depth 3)" -ForegroundColor Green
} catch {
    Write-Host "❌ Get todos endpoint failed: $($_.Exception.Message)" -ForegroundColor Red
}

# Test 3: MCP Protocol - Initialize
Write-Host "`n3. Testing MCP Protocol - Initialize..." -ForegroundColor Cyan
$initRequest = @{
    jsonrpc = "2.0"
    id = 1
    method = "initialize"
    params = @{
        protocolVersion = "2024-11-05"
        capabilities = @{
            tools = @{}
        }
        clientInfo = @{
            name = "test-client"
            version = "1.0.0"
        }
    }
} | ConvertTo-Json -Depth 4

try {
    $initResponse = Invoke-RestMethod -Uri "$baseUrl/mcp" -Method POST -Body $initRequest -ContentType "application/json"
    Write-Host "✅ MCP Initialize working: $($initResponse | ConvertTo-Json -Depth 3)" -ForegroundColor Green
} catch {
    Write-Host "❌ MCP Initialize failed: $($_.Exception.Message)" -ForegroundColor Red
}

# Test 4: MCP Protocol - List Tools
Write-Host "`n4. Testing MCP Protocol - List Tools..." -ForegroundColor Cyan
$toolsRequest = @{
    jsonrpc = "2.0"
    id = 2
    method = "tools/list"
    params = @{}
} | ConvertTo-Json -Depth 3

try {
    $toolsResponse = Invoke-RestMethod -Uri "$baseUrl/mcp" -Method POST -Body $toolsRequest -ContentType "application/json"
    Write-Host "✅ MCP Tools List working: $($toolsResponse | ConvertTo-Json -Depth 4)" -ForegroundColor Green
} catch {
    Write-Host "❌ MCP Tools List failed: $($_.Exception.Message)" -ForegroundColor Red
}

# Test 5: MCP Protocol - Add Todo Tool
Write-Host "`n5. Testing MCP Protocol - Add Todo Tool..." -ForegroundColor Cyan
$addTodoRequest = @{
    jsonrpc = "2.0"
    id = 3
    method = "tools/call"
    params = @{
        name = "add_todo"
        arguments = @{
            title = "Test Todo from MCP"
            isDone = $false
        }
    }
} | ConvertTo-Json -Depth 4

try {
    $addResponse = Invoke-RestMethod -Uri "$baseUrl/mcp" -Method POST -Body $addTodoRequest -ContentType "application/json"
    Write-Host "✅ MCP Add Todo working: $($addResponse | ConvertTo-Json -Depth 4)" -ForegroundColor Green
} catch {
    Write-Host "❌ MCP Add Todo failed: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host "`n🎉 MCP Server testing completed!" -ForegroundColor Green
Write-Host "Your MCP server should now be accessible at: $baseUrl/mcp" -ForegroundColor Yellow
