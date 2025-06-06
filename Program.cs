using TodoList.Components;
using Microsoft.Extensions.DependencyInjection;

var builder = WebApplication.CreateBuilder(args);

// Add services to the container.
builder.Services.AddRazorComponents()
    .AddInteractiveServerComponents();

// Add a singleton service for shared todo list
builder.Services.AddSingleton<TodoListService>();

var app = builder.Build();

// Configure the HTTP request pipeline.
if (!app.Environment.IsDevelopment())
{
    app.UseExceptionHandler("/Error", createScopeForErrors: true);
    // The default HSTS value is 30 days. You may want to change this for production scenarios, see https://aka.ms/aspnetcore-hsts.
    app.UseHsts();
}

// Remove HTTPS redirection
// app.UseHttpsRedirection();

app.UseAntiforgery();

// Add health check endpoint for Docker health checks
app.MapGet("/health", () => Results.Ok(new { status = "healthy", timestamp = DateTime.UtcNow }));

app.MapStaticAssets();
app.MapRazorComponents<App>()
    .AddInteractiveServerRenderMode();

// MCP server for add/remove support
var todoService = app.Services.GetRequiredService<TodoListService>();

// Create a builder for the MCP server and configure Kestrel for HTTP only
var mcpBuilder = WebApplication.CreateBuilder();
mcpBuilder.WebHost.ConfigureKestrel(options =>
{
    options.ListenAnyIP(5051); // Listen on all interfaces, not just localhost
});

// Use the same TodoListService instance for the MCP server
mcpBuilder.Services.AddSingleton(todoService);
var mcpApp = mcpBuilder.Build();

mcpApp.MapPost("/mcp/add", (TodoItem item) => {
    todoService.Add(item);
    return Results.Ok(todoService.GetAll());
});

mcpApp.MapPost("/mcp/remove", (TodoItem item) => {
    todoService.Remove(item.Title);
    return Results.Ok(todoService.GetAll());
});

mcpApp.MapPost("/mcp/markdone", (TodoItem item) => {
    todoService.MarkAsDone(item.Title, item.IsDone);
    return Results.Ok(todoService.GetAll());
});

mcpApp.MapGet("/mcp/todos", () => {
    var todos = todoService.GetAll();
    return Results.Ok(new { 
        success = true, 
        todos = todos.Select(t => new { title = t.Title, isDone = t.IsDone }).ToArray(),
        count = todos.Count
    });
});

// Add a minimal SSE endpoint for /mcp/ to avoid 404 for SSE clients
mcpApp.MapGet("/mcp/", async (HttpContext context) => {
    context.Response.Headers["Content-Type"] = "text/event-stream";
    await context.Response.Body.FlushAsync();
    // Keep the connection open for SSE clients
    while (!context.RequestAborted.IsCancellationRequested)
    {
        await context.Response.WriteAsync(": keep-alive\n\n");
        await context.Response.Body.FlushAsync();
        await Task.Delay(10000, context.RequestAborted); // send keep-alive every 10s
    }
});

// Add a POST endpoint for /mcp to handle JSON-RPC requests like initialize
mcpApp.MapPost("/mcp", async (HttpContext context) => {
    try {
        // Read and parse the JSON-RPC request
        using var reader = new System.IO.StreamReader(context.Request.Body);
        var requestBody = await reader.ReadToEndAsync();
        
        // Log the request for debugging
        Console.WriteLine($"Received MCP request: {requestBody}");
        
        var jsonRequest = System.Text.Json.JsonDocument.Parse(requestBody);
        
        // Check if it's an initialize request
        if (jsonRequest.RootElement.TryGetProperty("method", out var method) && 
            method.GetString() == "initialize" &&
            jsonRequest.RootElement.TryGetProperty("id", out var id))
        {
            // Return a properly formatted initialize response
            var response = new {
                jsonrpc = "2.0",
                id = id.GetInt32(),
                result = new {
                    serverInfo = new {
                        name = "TodoList MCP Server",
                        version = "1.0.0"
                    },
                    capabilities = new {
                        tools = new {
                            listChanged = false
                        }
                    }
                }
            };
            
            context.Response.ContentType = "application/json";
            await context.Response.WriteAsJsonAsync(response);
        }        else if (jsonRequest.RootElement.TryGetProperty("method", out var methodProp) && 
                 methodProp.GetString() == "tools/list" &&
                 jsonRequest.RootElement.TryGetProperty("id", out var toolsId))
        {            // Handle tools/list request
            var tools = new object[] {
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
                        properties = new {
                            title = new { type = "string", description = "The title of the todo item to remove" }
                        },
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
                    inputSchema = new {
                        type = "object",
                        properties = new { },
                        required = new string[] { }
                    }
                }
            };
            
            var response = new {
                jsonrpc = "2.0",
                id = toolsId.GetInt32(),
                result = new {
                    tools = tools
                }
            };
            
            context.Response.ContentType = "application/json";
            await context.Response.WriteAsJsonAsync(response);
        }
        else if (jsonRequest.RootElement.TryGetProperty("method", out var callMethod) && 
                 callMethod.GetString() == "tools/call" &&
                 jsonRequest.RootElement.TryGetProperty("id", out var callId))
        {            // Handle tool calls
            var paramsElement = jsonRequest.RootElement.GetProperty("params");
            var toolName = paramsElement.GetProperty("name").GetString()!;
            var arguments = paramsElement.GetProperty("arguments");
              object? result = null;
              switch (toolName)
            {
                case "add_todo":
                    var title = arguments.GetProperty("title").GetString()!;
                    var isDone = arguments.TryGetProperty("isDone", out var isDoneProperty) ? isDoneProperty.GetBoolean() : false;
                    todoService.Add(new TodoItem { Title = title, IsDone = isDone });
                    result = new { success = true, message = $"Added todo: {title}" };
                    break;
                    
                case "remove_todo":
                    var removeTitle = arguments.GetProperty("title").GetString()!;
                    todoService.Remove(removeTitle);
                    result = new { success = true, message = $"Removed todo: {removeTitle}" };
                    break;
                    
                case "mark_todo_done":
                    var markTitle = arguments.GetProperty("title").GetString()!;
                    var markDone = arguments.GetProperty("isDone").GetBoolean();
                    todoService.MarkAsDone(markTitle, markDone);
                    result = new { success = true, message = $"Marked todo '{markTitle}' as {(markDone ? "done" : "not done")}" };
                    break;
                    
                case "get_todos":
                    var allTodos = todoService.GetAll();
                    result = new { 
                        success = true, 
                        todos = allTodos.Select(t => new { title = t.Title, isDone = t.IsDone }).ToArray(),
                        count = allTodos.Count
                    };
                    break;
                    
                default:
                    result = new { success = false, message = $"Unknown tool: {toolName}" };
                    break;
            }
            
            var response = new {
                jsonrpc = "2.0",
                id = callId.GetInt32(),
                result = new {
                    content = new[] {
                        new {
                            type = "text",
                            text = System.Text.Json.JsonSerializer.Serialize(result)
                        }
                    }
                }
            };
            
            context.Response.ContentType = "application/json";
            await context.Response.WriteAsJsonAsync(response);
        }
        else 
        {
            // For other methods we don't implement yet, return a minimal success response
            var responseId = 1;
            if (jsonRequest.RootElement.TryGetProperty("id", out var reqId))
            {
                responseId = reqId.ValueKind == System.Text.Json.JsonValueKind.Number ? 
                    reqId.GetInt32() : responseId;
            }
            
            var response = new {
                jsonrpc = "2.0",
                id = responseId,
                result = new {}
            };
            
            context.Response.ContentType = "application/json";
            await context.Response.WriteAsJsonAsync(response);
        }
    }
    catch (Exception ex)
    {
        // Log the error
        Console.WriteLine($"Error processing JSON-RPC request: {ex.Message}");
        Console.WriteLine($"Stack trace: {ex.StackTrace}");
          // Return a JSON-RPC error response
        var errorResponse = new {
            jsonrpc = "2.0",
            id = (int?)null, // We don't know the real ID if parsing failed
            error = new {
                code = -32700,
                message = "Parse error",
                data = ex.Message
            }
        };
        
        context.Response.ContentType = "application/json";
        context.Response.StatusCode = 200; // JSON-RPC uses HTTP 200 even for errors
        await context.Response.WriteAsJsonAsync(errorResponse);
    }
});

mcpApp.MapGet("/mcp/tools", async (HttpContext context) => {
    context.Response.ContentType = "application/json";    
    var tools = new object[] {
        new {
            name = "add",
            description = "Add a todo item",
            parameters = new[] {
                new { name = "title", type = "string", required = true },
                new { name = "isDone", type = "boolean", required = false }
            }
        },
        new {
            name = "remove",
            description = "Remove a todo item by title",
            parameters = new[] {
                new { name = "title", type = "string", required = true }
            }
        },
        new {
            name = "markdone",
            description = "Mark a todo item as done or undone",
            parameters = new[] {
                new { name = "title", type = "string", required = true },
                new { name = "isDone", type = "boolean", required = true }
            }        },
        new {
            name = "get_todos",
            description = "Get the current list of all todo items",
            parameters = Array.Empty<object>()
        }
    };
    await context.Response.WriteAsJsonAsync(tools, context.RequestAborted);
    await context.Response.Body.FlushAsync(context.RequestAborted);
});

_ = Task.Run(async () => await mcpApp.RunAsync());

app.Run();
