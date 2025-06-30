using Microsoft.EntityFrameworkCore;
using TodoList.Components;

var builder = WebApplication.CreateBuilder(args);

// Configure services
ConfigureServices(builder);

var app = builder.Build();

// Configure middleware and database
await ConfigureAppAsync(app);

app.Run();

void ConfigureServices(WebApplicationBuilder builder)
{
    // Database configuration - PostgreSQL with SQLite fallback
    var connectionString = builder.Configuration.GetConnectionString("DefaultConnection");
    if (!string.IsNullOrEmpty(connectionString) && connectionString.Contains("Host="))
    {
        builder.Services.AddDbContext<TodoDbContext>(options =>
            options.UseNpgsql(connectionString));
    }
    else
    {
        var sqliteConnection = builder.Configuration.GetConnectionString("SqliteConnection") ?? "Data Source=todolist.db";
        builder.Services.AddDbContext<TodoDbContext>(options =>
            options.UseSqlite(sqliteConnection));
    }

    // CORS configuration for MCP clients
    builder.Services.AddCors(options =>
    {
        options.AddDefaultPolicy(policy =>
        {
            policy.AllowAnyOrigin()
                  .AllowAnyMethod()
                  .AllowAnyHeader();
        });
    });

    // Blazor services
    builder.Services.AddRazorComponents()
        .AddInteractiveServerComponents();

    // Application services
    builder.Services.AddScoped<TodoListService>();
}

async Task ConfigureAppAsync(WebApplication app)
{
    // Initialize database
    await InitializeDatabaseAsync(app);

    // Configure middleware
    if (!app.Environment.IsDevelopment())
    {
        app.UseExceptionHandler("/Error", createScopeForErrors: true);
        app.UseHsts();
    }

    // Enable CORS
    app.UseCors();

    app.UseAntiforgery();

    // Configure routes
    ConfigureRoutes(app);
}

void ConfigureRoutes(WebApplication app)
{
    // Health check
    app.MapGet("/health", () => Results.Ok(new { 
        status = "healthy", 
        timestamp = DateTime.UtcNow,
        environment = app.Environment.EnvironmentName 
    }));

    // Static assets and Blazor components
    app.MapStaticAssets();
    app.MapRazorComponents<App>()
        .AddInteractiveServerRenderMode();

    // MCP API endpoints
    ConfigureMcpRoutes(app);
}

void ConfigureMcpRoutes(WebApplication app)
{
    // Simple REST endpoints for todo operations
    app.MapGet("/mcp/todos", async (TodoListService service) => 
        Results.Ok(new { 
            success = true, 
            todos = (await service.GetAllAsync()).Select(t => new { t.Title, t.IsDone }),
            count = await service.GetCountAsync()
        }));

    app.MapPost("/mcp/todos", async (AddTodoRequest request, TodoListService service) => 
    {
        await service.AddAsync(new TodoItem { Title = request.Title, IsDone = request.IsDone });
        return Results.Ok(new { success = true, message = $"Added todo: {request.Title}" });
    });

    app.MapDelete("/mcp/todos/{title}", async (string title, TodoListService service) => 
    {
        await service.RemoveAsync(title);
        return Results.Ok(new { success = true, message = $"Removed todo: {title}" });
    });

    app.MapPut("/mcp/todos/{title}", async (string title, UpdateTodoRequest request, TodoListService service) => 
    {
        await service.MarkAsDoneAsync(title, request.IsDone);
        return Results.Ok(new { success = true, message = $"Updated todo: {title}" });
    });

    // MCP protocol endpoint for tool integration
    app.MapPost("/mcp", HandleMcpProtocol);
}

async Task InitializeDatabaseAsync(WebApplication app)
{
    using var scope = app.Services.CreateScope();
    var context = scope.ServiceProvider.GetRequiredService<TodoDbContext>();
    var logger = scope.ServiceProvider.GetRequiredService<ILogger<Program>>();
    
    try
    {
        await context.Database.EnsureCreatedAsync();
        logger.LogInformation("Database initialized successfully");
        
        // Seed sample data if empty
        if (!await context.TodoItems.AnyAsync())
        {
            var sampleTodos = new[]
            {
                new TodoItem { Title = "Learn Entity Framework Core", IsDone = false },
                new TodoItem { Title = "Setup PostgreSQL Database", IsDone = true },
                new TodoItem { Title = "Create Todo App", IsDone = false }
            };
            
            context.TodoItems.AddRange(sampleTodos);
            await context.SaveChangesAsync();
            logger.LogInformation("Sample data seeded successfully");
        }
    }
    catch (Exception ex)
    {
        logger.LogError(ex, "Database initialization failed");
        throw; // Re-throw to prevent app from starting with broken database
    }
}

async Task<IResult> HandleMcpProtocol(HttpContext context, TodoListService service)
{
    var logger = context.RequestServices.GetRequiredService<ILogger<Program>>();
    
    try 
    {
        using var reader = new StreamReader(context.Request.Body);
        var requestBody = await reader.ReadToEndAsync();
        
        logger.LogInformation("MCP Request received: {RequestBody}", requestBody);
        
        if (string.IsNullOrWhiteSpace(requestBody))
        {
            logger.LogWarning("Empty MCP request body");
            return Results.BadRequest(new { 
                jsonrpc = "2.0", 
                id = (int?)null, 
                error = new { code = -32700, message = "Empty request body" } 
            });
        }
        
        var jsonRequest = System.Text.Json.JsonDocument.Parse(requestBody);
        
        if (!jsonRequest.RootElement.TryGetProperty("method", out var method))
        {
            logger.LogWarning("Invalid MCP request format: missing method");
            return Results.BadRequest(new { 
                jsonrpc = "2.0", 
                id = (int?)null, 
                error = new { code = -32600, message = "Invalid MCP request format" } 
            });
        }

        var methodName = method.GetString();
        var hasId = jsonRequest.RootElement.TryGetProperty("id", out var id);
        var responseId = hasId ? id.GetInt32() : (int?)null;
        
        logger.LogInformation("Processing MCP method: {Method} with ID: {Id}", methodName, responseId);
        
        // Handle notifications (no response needed)
        if (!hasId && methodName?.StartsWith("notifications/") == true)
        {
            logger.LogInformation("Handling notification: {Method}", methodName);
            return Results.Ok();
        }
        
        object result = methodName switch
        {
            "initialize" => CreateInitializeResponse(),
            "tools/list" => CreateToolsListResponse(),
            "tools/call" => await HandleToolCallAsync(jsonRequest, service),
            "ping" => new { acknowledged = true },
            "notifications/initialized" => new { acknowledged = true },
            _ => new { error = $"Unknown method: {methodName}" }
        };
        
        var response = new { jsonrpc = "2.0", id = responseId, result };
        logger.LogInformation("MCP Response: {Response}", System.Text.Json.JsonSerializer.Serialize(response));
        return Results.Ok(response);
    }
    catch (System.Text.Json.JsonException jsonEx)
    {
        logger.LogError(jsonEx, "JSON parsing error in MCP request");
        var errorResponse = new {
            jsonrpc = "2.0",
            id = (int?)null,
            error = new { code = -32700, message = "Parse error", data = jsonEx.Message }
        };
        
        return Results.BadRequest(errorResponse);
    }
    catch (Exception ex)
    {
        logger.LogError(ex, "Unexpected error in MCP request handling");
        var errorResponse = new {
            jsonrpc = "2.0",
            id = (int?)null,
            error = new { code = -32603, message = "Internal error", data = ex.Message }
        };
        
        return Results.BadRequest(errorResponse);
    }
}

object CreateInitializeResponse() => new {
    protocolVersion = "2024-11-05",
    serverInfo = new { name = "TodoList MCP Server", version = "2.0.0" },
    capabilities = new { 
        tools = new { listChanged = false },
        logging = new { },
        prompts = new { },
        resources = new { }
    }
};

object CreateToolsListResponse() => new {
    tools = new object[] {
        new {
            name = "add_todo",
            description = "Add a new todo item",
            inputSchema = new {
                type = "object",
                properties = new {
                    title = new { type = "string", description = "The title of the todo item" },
                    isDone = new { type = "boolean", description = "Whether the todo is completed", @default = false }
                },
                required = new[] { "title" }
            }
        },
        new {
            name = "remove_todo",
            description = "Remove a todo item by title",
            inputSchema = new {
                type = "object",
                properties = new { title = new { type = "string", description = "The title of the todo item to remove" } },
                required = new[] { "title" }
            }
        },
        new {
            name = "mark_todo_done",
            description = "Mark a todo item as done or undone",
            inputSchema = new {
                type = "object",
                properties = new {
                    title = new { type = "string", description = "The title of the todo item" },
                    isDone = new { type = "boolean", description = "Whether the todo should be marked as done" }
                },
                required = new[] { "title", "isDone" }
            }
        },
        new {
            name = "get_todos",
            description = "Get the current list of all todo items",
            inputSchema = new { type = "object", properties = new { }, required = new string[] { } }
        }
    }
};

async Task<object> HandleToolCallAsync(System.Text.Json.JsonDocument jsonRequest, TodoListService service)
{
    var paramsElement = jsonRequest.RootElement.GetProperty("params");
    var toolName = paramsElement.GetProperty("name").GetString()!;
    var arguments = paramsElement.GetProperty("arguments");
    
    object toolResult = toolName switch
    {
        "add_todo" => await HandleAddTodoAsync(arguments, service),
        "remove_todo" => await HandleRemoveTodoAsync(arguments, service),
        "mark_todo_done" => await HandleMarkTodoAsync(arguments, service),
        "get_todos" => await HandleGetTodosAsync(service),
        _ => new { success = false, message = $"Unknown tool: {toolName}" }
    };

    return new {
        content = new[] {
            new { type = "text", text = System.Text.Json.JsonSerializer.Serialize(toolResult) }
        }
    };
}

async Task<object> HandleAddTodoAsync(System.Text.Json.JsonElement arguments, TodoListService service)
{
    var title = arguments.GetProperty("title").GetString()!;
    var isDone = arguments.TryGetProperty("isDone", out var isDoneProperty) ? isDoneProperty.GetBoolean() : false;
    await service.AddAsync(new TodoItem { Title = title, IsDone = isDone });
    return new { success = true, message = $"Added todo: {title}" };
}

async Task<object> HandleRemoveTodoAsync(System.Text.Json.JsonElement arguments, TodoListService service)
{
    var title = arguments.GetProperty("title").GetString()!;
    await service.RemoveAsync(title);
    return new { success = true, message = $"Removed todo: {title}" };
}

async Task<object> HandleMarkTodoAsync(System.Text.Json.JsonElement arguments, TodoListService service)
{
    var title = arguments.GetProperty("title").GetString()!;
    var isDone = arguments.GetProperty("isDone").GetBoolean();
    await service.MarkAsDoneAsync(title, isDone);
    return new { success = true, message = $"Marked todo '{title}' as {(isDone ? "done" : "not done")}" };
}

async Task<object> HandleGetTodosAsync(TodoListService service)
{
    var todos = await service.GetAllAsync();
    return new { 
        success = true, 
        todos = todos.Select(t => new { t.Title, t.IsDone }),
        count = todos.Count
    };
}

// Request DTOs for clean API contracts
public record AddTodoRequest(string Title, bool IsDone = false);
public record UpdateTodoRequest(bool IsDone);
