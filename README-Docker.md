# TodoList MCP Server - Docker Guide

This is a .NET 9.0 TodoList application that provides both a web interface and an MCP (Model Context Protocol) server for AI assistants.

## Features

- **Web Interface**: Blazor Server application on port 8080
- **MCP Server**: JSON-RPC server on port 5051 for AI assistant integration
- **CRUD Operations**: Add, remove, mark as done/undone todo items
- **Health Monitoring**: Built-in health check endpoint
- **Security**: Runs as non-root user in container

## MCP Tools Available

The MCP server provides these tools for AI assistants:

1. **add_todo**: Add a new todo item
   - Parameters: `title` (required), `isDone` (optional, default: false)

2. **remove_todo**: Remove a todo item by title
   - Parameters: `title` (required)

3. **mark_todo_done**: Mark a todo as done or undone
   - Parameters: `title` (required), `isDone` (required)

4. **get_todos**: Get the current list of all todo items
   - Parameters: None

## Quick Start

### Option 1: Using Docker Compose (Recommended)

```bash
# Build and run
docker-compose up --build

# Run in background
docker-compose up -d --build

# Stop the service
docker-compose down
```

### Option 2: Using Docker directly

```bash
# Build the image
docker build -t todolist-mcp .

# Run the container
docker run -d `
  --name todolist-mcp `
  -p 8080:8080 `
  -p 5051:5051 `
  --restart unless-stopped `
  todolist-mcp

# Stop the container
docker stop todolist-mcp
docker rm todolist-mcp
```

## Accessing the Application

- **Web Interface**: http://localhost:8080
- **Health Check**: http://localhost:8080/health
- **MCP Server**: http://localhost:5051/mcp (JSON-RPC endpoint)
- **MCP Tools List**: http://localhost:5051/mcp/tools

## MCP Server Endpoints

### JSON-RPC Endpoints (Primary)

- `POST /mcp` - Main JSON-RPC endpoint for MCP protocol
  - Supports `initialize`, `tools/list`, `tools/call` methods
  
### REST API Endpoints (Alternative)

- `POST /mcp/add` - Add todo item
- `POST /mcp/remove` - Remove todo item  
- `POST /mcp/markdone` - Mark todo as done/undone
- `GET /mcp/todos` - Get all todo items
- `GET /mcp/tools` - List available tools
- `GET /mcp/` - SSE endpoint for streaming

## Testing the MCP Server

### Test MCP Initialize

```powershell
$body = @{
    jsonrpc = "2.0"
    id = 1
    method = "initialize"
    params = @{
        protocolVersion = "2024-11-05"
        capabilities = @{}
        clientInfo = @{
            name = "test-client"
            version = "1.0.0"
        }
    }
} | ConvertTo-Json -Depth 3

Invoke-RestMethod -Uri "http://localhost:5051/mcp" -Method POST -Body $body -ContentType "application/json"
```

### Test Tools List

```powershell
$body = @{
    jsonrpc = "2.0"
    id = 2
    method = "tools/list"
    params = @{}
} | ConvertTo-Json

Invoke-RestMethod -Uri "http://localhost:5051/mcp" -Method POST -Body $body -ContentType "application/json"
```

### Test Add Todo

```powershell
$body = @{
    jsonrpc = "2.0"
    id = 3
    method = "tools/call"
    params = @{
        name = "add_todo"
        arguments = @{
            title = "Test Todo Item"
            isDone = $false
        }
    }
} | ConvertTo-Json -Depth 3

Invoke-RestMethod -Uri "http://localhost:5051/mcp" -Method POST -Body $body -ContentType "application/json"
```

### Test Get Todos

```powershell
$body = @{
    jsonrpc = "2.0"
    id = 4
    method = "tools/call"
    params = @{
        name = "get_todos"
        arguments = @{}
    }
} | ConvertTo-Json -Depth 3

Invoke-RestMethod -Uri "http://localhost:5051/mcp" -Method POST -Body $body -ContentType "application/json"
```

## Using with AI Assistants

This MCP server can be integrated with AI assistants that support the Model Context Protocol. Configure your AI assistant to connect to:

- **MCP Server URL**: `http://localhost:5051/mcp`
- **Protocol**: JSON-RPC over HTTP
- **Available Tools**: add_todo, remove_todo, mark_todo_done, get_todos

## Development

### Local Development

```powershell
# Run without Docker
dotnet run

# The app will be available at:
# - Web: http://localhost:5000 or https://localhost:5001
# - MCP: http://localhost:5051
```

### Building for Production

```powershell
# Build optimized image
docker build -t todolist-mcp:latest .

# Or with specific tag
docker build -t todolist-mcp:v1.0.0 .
```

## Monitoring

### Health Checks

The application includes built-in health monitoring:

```powershell
# Check application health
Invoke-RestMethod -Uri "http://localhost:8080/health"

# Expected response:
# {"status":"healthy","timestamp":"2024-01-01T00:00:00.000Z"}
```

### Docker Health Check

The container includes automatic health checking:

```powershell
# Check container health
docker ps

# View health check logs
docker inspect todolist-mcp --format='{{.State.Health.Status}}'
```

### Logs

```powershell
# View container logs
docker logs todolist-mcp

# Follow logs in real-time
docker logs -f todolist-mcp

# With docker-compose
docker-compose logs -f
```

## Troubleshooting

### Port Conflicts

If ports 8080 or 5051 are already in use:

```powershell
# Change ports in docker-compose.yml or use different ports:
docker run -p 8081:8080 -p 5052:5051 todolist-mcp
```

### Container Won't Start

```powershell
# Check container logs
docker logs todolist-mcp

# Verify image was built correctly
docker images | Where-Object { $_.Repository -like "*todolist-mcp*" }

# Rebuild if necessary
docker build --no-cache -t todolist-mcp .
```

### MCP Server Not Responding

1. Verify the container is running: `docker ps`
2. Check port binding: `docker port todolist-mcp`
3. Test health endpoint: `Invoke-RestMethod -Uri "http://localhost:8080/health"`
4. Check logs: `docker logs todolist-mcp`

## Security Considerations

- Container runs as non-root user (`appuser`)
- Only necessary ports are exposed
- Health checks prevent unhealthy containers from serving traffic
- No sensitive data is logged

## Architecture

```
┌─────────────────┐    ┌─────────────────┐
│   Web Browser   │────│   Port 8080     │
└─────────────────┘    │   Blazor UI     │
                       └─────────────────┘
                              │
┌─────────────────┐           │
│  AI Assistant   │────┐      │
└─────────────────┘    │      │
                       │      ▼
┌─────────────────┐    │ ┌─────────────────┐
│  MCP Client     │────┼─│ TodoList App    │
└─────────────────┘    │ │                 │
                       │ │ ┌─────────────┐ │
                       └─┼─│ MCP Server  │ │
                         │ │ Port 5051   │ │
                         │ └─────────────┘ │
                         │                 │
                         │ ┌─────────────┐ │
                         │ │TodoService  │ │
                         │ │(In-Memory)  │ │
                         │ └─────────────┘ │
                         └─────────────────┘
```

This setup provides a complete TodoList solution with both human and AI assistant interfaces.
