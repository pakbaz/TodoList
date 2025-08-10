# TodoList Project - Copilot Instructions

## Project Overview

This is a modern TodoList application built with .NET 9 Blazor Server and PostgreSQL database, featuring both web UI and MCP (Model Context Protocol) integration for AI assistant compatibility.

## Architecture

### Single Application Instance
- **Unified Architecture**: One process serves both web UI and MCP endpoints
- **Port Consolidation**: All services accessible through port 8080 (Docker) or 5000 (local)
- **Async-First**: All database operations are asynchronous for optimal performance

### Technology Stack
- **.NET 9**: Latest .NET framework
- **Blazor Server**: Interactive server-side rendering
- **Entity Framework Core**: ORM with async operations
- **PostgreSQL**: Primary production database
- **SQLite**: Automatic fallback for local development
- **Docker & Docker Compose**: Full containerization support
- **MCP Protocol**: AI assistant integration

### Database Strategy
- **PostgreSQL Primary**: Production-ready with Docker
- **SQLite Fallback**: Automatic fallback when PostgreSQL unavailable
- **Connection Detection**: Smart connection string detection
- **Auto-Migration**: Database schema created automatically
- **Sample Data**: Automatic seeding with sample todos

## Key Files & Structure

### Core Application Files
- `Program.cs` - Main application entry point with modular configuration
- `TodoDbContext.cs` - Entity Framework Core database context
- `TodoListService.cs` - Business logic and async data access layer
- `TodoItem.cs` - Data model with EF Core attributes

### Configuration Files
- `appsettings.json` - Base configuration
- `appsettings.Development.json` - Local development settings
- `appsettings.Production.json` - Docker/production settings
- `docker-compose.yml` - Multi-container Docker setup
- `Dockerfile` - Application container definition

### Database Setup Files
- `database-setup.sql` - PostgreSQL database initialization script
- `setup-database.ps1` - PowerShell script for easy database setup

### Blazor Components
- `Components/App.razor` - Root application component
- `Components/Pages/Todo.razor` - Main todo management page
- `Components/Layout/MainLayout.razor` - Application layout

## Development Guidelines

### Code Style & Patterns
- **Async/Await**: Use async methods for all I/O operations
- **Dependency Injection**: Use scoped services for data access
- **Clean Architecture**: Separate concerns (data, business logic, presentation)
- **Error Handling**: Comprehensive error handling with logging
- **Resource Management**: Proper disposal of resources (using statements)

### Database Patterns
```csharp
// Always use async methods
public async Task<IReadOnlyList<TodoItem>> GetAllAsync()
{
    using var scope = _scopeFactory.CreateScope();
    var context = scope.ServiceProvider.GetRequiredService<TodoDbContext>();
    return await context.TodoItems.OrderBy(t => t.CreatedAt).ToListAsync();
}

// Use scoped contexts to avoid concurrency issues
using var scope = _scopeFactory.CreateScope();
var context = scope.ServiceProvider.GetRequiredService<TodoDbContext>();
```

### Configuration Patterns
```csharp
// Smart connection string detection
var connectionString = builder.Configuration.GetConnectionString("DefaultConnection");
if (!string.IsNullOrEmpty(connectionString) && connectionString.Contains("Host="))
{
    // PostgreSQL
    builder.Services.AddDbContext<TodoDbContext>(options =>
        options.UseNpgsql(connectionString));
}
else
{
    // SQLite fallback
    builder.Services.AddDbContext<TodoDbContext>(options =>
        options.UseSqlite(sqliteConnection));
}
```

## API Endpoints

### Health & Monitoring
- `GET /health` - Application health status with environment info

### REST API (MCP Integration)
- `GET /mcp/todos` - Get all todos with count
- `POST /mcp/todos` - Add new todo (JSON: `{"title": "...", "isDone": false}`)
- `PUT /mcp/todos/{title}` - Update todo status (JSON: `{"isDone": true}`)
- `DELETE /mcp/todos/{title}` - Remove todo by title

### MCP Protocol
- `POST /mcp` - Full MCP protocol endpoint for AI tool integration

## Database Schema

### TodoItem Entity
```csharp
public class TodoItem
{
    [Key]
    public int Id { get; set; }
    
    [Required]
    [MaxLength(500)]
    public string Title { get; set; } = string.Empty;
    
    public bool IsDone { get; set; }
    
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
}
```

### Connection Strings
- **PostgreSQL**: `Host=postgresql;Database=todolistdb;Username=admin;Password=password`
- **Local PostgreSQL**: `Host=localhost;Database=todolistdb;Username=admin;Password=password`
- **SQLite**: `Data Source=todolist.db`

## Development Workflows

### Local Development
```bash
# Install dependencies and run with SQLite fallback
dotnet restore
dotnet run

# Access at:
# - Web UI: http://localhost:5000
# - Health: http://localhost:5000/health
# - MCP API: http://localhost:5000/mcp/todos
```

### Docker Development
```bash
# Start PostgreSQL and application
docker-compose up -d

# Access at:
# - Web UI: http://localhost:8080
# - Health: http://localhost:8080/health
# - MCP API: http://localhost:8080/mcp/todos

# View logs
docker-compose logs -f todolist-app

# Stop services
docker-compose down
```

### Database Setup
```bash
# Automatic with Docker
docker-compose up -d

# Manual PostgreSQL setup
./setup-database.ps1

# The application handles database creation automatically
```

## Common Development Tasks

### Adding New Todo Operations
1. Add method to `TodoListService.cs` (async pattern)
2. Add endpoint to `ConfigureMcpRoutes()` in `Program.cs`
3. Update MCP tools list if needed for AI integration
4. Test with both REST API and web UI

### Database Changes
1. Update `TodoItem.cs` model
2. Update `TodoDbContext.cs` if needed
3. Database migrations handled automatically with `EnsureCreatedAsync()`
4. For production, consider explicit migrations

### Adding New Blazor Components
1. Create in `Components/` directory
2. Follow existing naming conventions
3. Use `@rendermode InteractiveServer` for interactivity
4. Import in `_Imports.razor` if creating reusable components

## Environment Configuration

### Development Environment
- Uses `appsettings.Development.json`
- Automatic SQLite fallback
- Detailed logging enabled
- Local PostgreSQL on port 5432

### Production Environment (Docker)
- Uses `appsettings.Production.json`
- PostgreSQL required
- Production logging levels
- Health checks enabled
- Container networking

## Troubleshooting

### Database Connection Issues
1. Check if PostgreSQL container is running: `docker-compose ps`
2. Verify connection string in appropriate appsettings file
3. Application automatically falls back to SQLite if PostgreSQL unavailable
4. Check logs: `docker-compose logs todolist-app`

### Port Conflicts
- Default ports: 8080 (Docker), 5000 (local), 5432 (PostgreSQL)
- Modify `docker-compose.yml` or `launchSettings.json` to change ports
- Ensure no other services are using these ports

### Container Issues
```bash
# Rebuild containers from scratch
docker-compose down
docker-compose build --no-cache
docker-compose up -d
```

## MCP Integration Details

### Supported Tools
- `add_todo` - Add new todo with title and optional done status
- `remove_todo` - Remove todo by exact title match
- `mark_todo_done` - Toggle todo completion status
- `get_todos` - Retrieve all todos with metadata

### AI Assistant Usage
The MCP endpoint at `/mcp` supports full JSON-RPC 2.0 protocol for seamless integration with AI assistants. The application provides both simple REST endpoints and full MCP protocol support.

## Security Considerations

### Database Security
- Use environment variables for sensitive connection strings
- PostgreSQL credentials should be changed from defaults in production
- SQLite database files are gitignored

### Web Security
- HTTPS enforced in production
- Antiforgery tokens enabled
- HSTS headers in production
- Proper error handling without information disclosure

## Performance Optimization

### Database Performance
- All operations are async
- Connection pooling via Entity Framework
- Proper resource disposal with scoped contexts
- Indexed queries where appropriate

### Application Performance
- Blazor Server for optimal initial load
- Static asset optimization
- Health checks for monitoring
- Structured logging for debugging

Remember: This project emphasizes simplicity, maintainability, and modern .NET practices while providing both traditional web UI and modern AI integration capabilities.