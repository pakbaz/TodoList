# GitHub Copilot Instructions for TodoList Project

## Project Overview

This is a modern TodoList application built with **.NET 9 Blazor Server** and **PostgreSQL**, featuring enterprise-grade Infrastructure as Code (IaC) and CI/CD pipeline deployment to **Azure Container Apps**.

### Tech Stack
- **Backend**: ASP.NET Core .NET 9 with Blazor Server
- **Database**: PostgreSQL (primary) with SQLite fallback for local development
- **ORM**: Entity Framework Core 9.0 with Npgsql provider
- **Frontend**: Blazor Server components with interactive server-side rendering
- **Cloud**: Azure Container Apps, Azure Container Registry, Azure Database for PostgreSQL
- **Infrastructure**: Bicep templates with Azure Verified Modules
- **CI/CD**: GitHub Actions with OIDC authentication
- **Monitoring**: Application Insights, Log Analytics Workspace
- **Containerization**: Docker with multi-stage builds

## Code Style and Conventions

### C# Conventions
- Use **nullable reference types** (`<Nullable>enable</Nullable>`)
- Follow **async/await** patterns consistently
- Use **dependency injection** for service registration
- Implement proper **error handling** with try-catch blocks and logging
- Use **cancellation tokens** for async operations
- Follow **SOLID principles** and clean architecture patterns

### Naming Conventions
- **Classes**: PascalCase (e.g., `TodoListService`, `TodoDbContext`)
- **Methods**: PascalCase with descriptive names (e.g., `GetAllAsync`, `MarkAsDoneAsync`)
- **Properties**: PascalCase (e.g., `Title`, `IsDone`, `CreatedAt`)
- **Fields**: camelCase with underscore prefix (e.g., `_context`, `_logger`)
- **Parameters**: camelCase (e.g., `cancellationToken`, `todoId`)

### Database Conventions
- **Table names**: PascalCase (e.g., `TodoItems`)
- **Column names**: PascalCase matching property names
- Use **data annotations** for validation (`[Required]`, `[StringLength]`)
- Implement **audit fields** (`CreatedAt`, `UpdatedAt`)
- Use **database-generated** identity columns for primary keys

## Project Structure

```
TodoList/
├── Components/           # Blazor components and pages
│   ├── Pages/           # Razor pages (Todo.razor)
│   └── Layout/          # Layout components
├── Models/              # Entity models (TodoItem.cs)
├── Services/            # Business logic services (TodoListService.cs)
├── Data/               # Database context (TodoDbContext.cs)
├── Tests/              # Unit tests
├── infra/              # Bicep infrastructure templates
├── docs/               # Architecture documentation
├── wwwroot/            # Static assets
└── docker-compose.yml  # Local development setup
```

## Key Components

### 1. TodoItem Model
- Primary entity with `Id`, `Title`, `IsDone`, `CreatedAt`, `UpdatedAt`
- Uses data annotations for validation
- Includes audit timestamps

### 2. TodoDbContext
- Entity Framework Core context
- Supports both PostgreSQL and SQLite
- Implements audit fields automatically
- Includes proper error handling and logging

### 3. TodoListService
- Business logic layer with full CRUD operations
- Async methods with cancellation token support
- Comprehensive error handling and logging
- Uses `IReadOnlyList<T>` for query results

### 4. Blazor Components
- Interactive server-side rendering
- Real-time UI updates
- Proper disposal of resources

## Development Guidelines

### Database Operations
```csharp
// Always use async operations with cancellation tokens
public async Task<IReadOnlyList<TodoItem>> GetAllAsync(CancellationToken cancellationToken = default)
{
    try
    {
        return await _context.TodoItems
            .OrderBy(t => t.CreatedAt)
            .AsNoTracking()
            .ToListAsync(cancellationToken);
    }
    catch (Exception ex)
    {
        _logger.LogError(ex, "Error retrieving todo items");
        throw;
    }
}
```

### Service Registration
```csharp
// Register services with proper lifetime scopes
builder.Services.AddScoped<TodoListService>();
builder.Services.AddDbContext<TodoDbContext>(options => 
    options.UseNpgsql(connectionString));
```

### Error Handling
- Always log exceptions with structured logging
- Use specific exception types when appropriate
- Implement proper HTTP status codes for API endpoints
- Handle database concurrency conflicts

### Testing
- Write unit tests for all service methods
- Use in-memory database for testing
- Mock external dependencies
- Test both success and failure scenarios

## Infrastructure Guidelines

### Docker
- Use multi-stage builds for optimization
- Expose port 8080 for Azure Container Apps
- Include health check endpoint (`/health`)
- Use non-root user for security

### Azure Resources
- **Container Apps**: Use system-assigned managed identity
- **Key Vault**: Store connection strings and secrets
- **PostgreSQL**: Enable connection retry logic
- **Application Insights**: Configure structured logging

### Bicep Templates
- Use Azure Verified Modules
- Implement proper RBAC assignments
- Configure diagnostic settings
- Use managed identities for authentication

## API Conventions

### REST Endpoints
- Use HTTP verbs correctly (GET, POST, PUT, DELETE)
- Return appropriate status codes
- Implement proper content negotiation
- Include validation and error responses

### MCP Protocol Support
- Implement JSON-RPC 2.0 endpoints
- Support batch operations
- Provide comprehensive error messages
- Enable AI assistant integration

## Security Best Practices

### Authentication & Authorization
- Use Azure AD integration when available
- Implement proper CORS policies for MCP clients
- Validate input data thoroughly
- Use HTTPS in production

### Secrets Management
- Store secrets in Azure Key Vault
- Use managed identities for authentication
- Never commit secrets to source control
- Rotate secrets regularly

### Data Protection
- Implement SQL injection protection (EF Core provides this)
- Validate all user inputs
- Use parameterized queries
- Enable audit logging

## Performance Considerations

### Database
- Use `AsNoTracking()` for read-only queries
- Implement connection pooling
- Add appropriate database indexes
- Use pagination for large result sets

### Caching
- Implement response caching where appropriate
- Use memory cache for frequently accessed data
- Consider Redis for distributed scenarios

### Monitoring
- Log performance metrics
- Monitor database query performance
- Track memory usage and garbage collection
- Set up alerts for critical issues

## AI Assistant Integration

### MCP Protocol
- Implement standard MCP endpoints (`/mcp`)
- Support todo item CRUD operations
- Provide comprehensive error responses
- Enable batch operations for efficiency

### Usage Examples
```csharp
// Add multiple todos
await todoService.AddTodosAsync(new[] { "Task 1", "Task 2" }, cancellationToken);

// Mark todo as completed
await todoService.MarkAsDoneAsync(todoId, true, cancellationToken);

// Get filtered todos
var activeTodos = await todoService.GetActiveAsync(cancellationToken);
```

## Common Patterns

### Service Method Template
```csharp
public async Task<Result> MethodAsync(Parameters parameters, CancellationToken cancellationToken = default)
{
    try
    {
        // Validate input
        if (/* validation fails */)
        {
            _logger.LogWarning("Validation failed for {Method}", nameof(MethodAsync));
            throw new ArgumentException("Validation message");
        }

        // Perform operation
        var result = await _context.SomeOperation
            .Where(/* conditions */)
            .FirstOrDefaultAsync(cancellationToken);

        // Log success
        _logger.LogDebug("Successfully completed {Method}", nameof(MethodAsync));
        
        return result;
    }
    catch (Exception ex)
    {
        _logger.LogError(ex, "Error in {Method}", nameof(MethodAsync));
        throw;
    }
}
```

### Blazor Component Pattern
```razor
@inject TodoListService TodoService
@implements IDisposable

<div class="component-container">
    <!-- Component markup -->
</div>

@code {
    private CancellationTokenSource _cancellationTokenSource = new();
    
    protected override async Task OnInitializedAsync()
    {
        // Initialize component
        await LoadDataAsync();
    }
    
    private async Task LoadDataAsync()
    {
        try
        {
            // Load data with cancellation support
        }
        catch (Exception ex)
        {
            // Handle errors
        }
    }
    
    public void Dispose()
    {
        _cancellationTokenSource?.Cancel();
        _cancellationTokenSource?.Dispose();
    }
}
```

## When Making Changes

1. **Always preserve existing patterns** and conventions
2. **Add proper logging** for new operations
3. **Include unit tests** for new functionality
4. **Update documentation** if adding new features
5. **Follow async/await patterns** consistently
6. **Use dependency injection** for new services
7. **Implement proper error handling**
8. **Consider performance implications**
9. **Maintain backward compatibility** when possible
10. **Test with both PostgreSQL and SQLite** configurations

This project emphasizes clean architecture, proper error handling, comprehensive logging, and enterprise-grade deployment practices. Always consider the cloud-native deployment model when making architectural decisions.
