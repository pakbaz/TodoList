# TodoList - .NET Blazor with PostgreSQL

A modern Todo application built with .NET 9 Blazor Server and PostgreSQL, featuring both web UI and MCP (Model Context Protocol) integration.

## Features

- **Blazor Server UI**: Interactive web interface for managing todos
- **PostgreSQL Database**: Production-ready data storage with SQLite fallback
- **MCP Integration**: Model Context Protocol support for AI tool integration
- **Docker Support**: Full containerization with Docker Compose
- **REST API**: Clean RESTful endpoints for todo operations
- **Health Checks**: Built-in health monitoring

## Quick Start

### With Docker (Recommended)

```bash
# Start the application with PostgreSQL
docker-compose up -d

# The application will be available at:
# - Web UI: http://localhost:8080
# - Health Check: http://localhost:8080/health
# - MCP API: http://localhost:8080/mcp/todos
```

### Local Development

```bash
# Install dependencies
dotnet restore

# Run with SQLite fallback
dotnet run

# The application will be available at:
# - Web UI: http://localhost:5000
# - Health Check: http://localhost:5000/health
# - MCP API: http://localhost:5000/mcp/todos
```

## API Endpoints

### Health Check
- `GET /health` - Application health status

### REST API
- `GET /mcp/todos` - Get all todos
- `POST /mcp/todos` - Add new todo
- `PUT /mcp/todos/{title}` - Update todo status
- `DELETE /mcp/todos/{title}` - Remove todo

### MCP Protocol
- `POST /mcp` - MCP protocol endpoint for AI tool integration

## Database Setup

### PostgreSQL (Docker)
The PostgreSQL database is automatically initialized with Docker Compose.

### Manual PostgreSQL Setup
If you want to set up PostgreSQL manually:

```bash
# Run the setup script
./setup-database.ps1
```

### SQLite Fallback
The application automatically falls back to SQLite if PostgreSQL is not available.

## Configuration

### Connection Strings
- **PostgreSQL**: `Host=localhost;Database=todolistdb;Username=admin;Password=password`
- **SQLite**: `Data Source=todolist.db`

### Environment Variables
- `ASPNETCORE_ENVIRONMENT`: Set to `Development` or `Production`
- `ConnectionStrings__DefaultConnection`: Override default connection string

## Architecture

The application has been refactored for simplicity and maintainability:

- **Program.cs**: Clean, modular configuration with separated concerns
- **TodoDbContext.cs**: Entity Framework Core database context
- **TodoListService.cs**: Async-only business logic and data access layer
- **TodoItem.cs**: Data model with EF Core attributes
- **Components/**: Blazor components and pages

- ✅ **Simplified Architecture**: Single app instance serving both web UI and MCP endpoints
- ✅ **Async-First**: All database operations are async for better performance
- ✅ **Clean Separation**: Modular Program.cs with clear separation of concerns
- ✅ **RESTful API**: Modern HTTP endpoints following REST conventions
- ✅ **Proper Error Handling**: Comprehensive error handling with logging
- ✅ **Docker Optimized**: Single port (8080) for all services
- ✅ **Health Monitoring**: Enhanced health checks with environment info

### Map

TodoList/
├── .dockerignore
├── .gitignore  
├── .vscode/
│   └── mcp.json
├── appsettings.json
├── appsettings.Development.json
├── appsettings.Production.json
├── Components/
│   ├── App.razor
│   ├── Routes.razor
│   ├── _Imports.razor
│   ├── Layout/
│   │   ├── MainLayout.razor
│   │   └── MainLayout.razor.css
│   └── Pages/
│       ├── Error.razor
│       ├── Todo.razor
│       └── Todo.razor.css
├── database-setup.sql
├── docker-compose.yml
├── Dockerfile
├── Program.cs
├── Properties/
│   └── launchSettings.json
├── README.md
├── setup-database.ps1
├── TodoDbContext.cs
├── TodoItem.cs
├── TodoList.csproj
├── TodoList.sln
├── TodoListService.cs
└── wwwroot/
    ├── app.css
    └── favicon.png

## Technology Stack

- .NET 9
- Blazor Server
- Entity Framework Core
- PostgreSQL / SQLite
- Docker & Docker Compose
- MCP (Model Context Protocol)

## Development

### Building
```bash
dotnet build
```

### Docker
```bash
# Start services
docker-compose up -d

# View logs
docker-compose logs -f

# Stop services
docker-compose down
```

## Troubleshooting

### Database Connection Issues
1. Ensure PostgreSQL is running: `docker-compose ps`
2. Check connection string in `appsettings.json`
3. Application automatically falls back to SQLite if PostgreSQL is unavailable

### Port Conflicts
- Default ports: 8080 (web + MCP), 5432 (PostgreSQL)
- Modify `docker-compose.yml` to change port mappings

### Container Issues
```bash
# Rebuild containers
docker-compose down
docker-compose build --no-cache
docker-compose up -d
```

## License

This project is licensed under the MIT License.
