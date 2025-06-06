using TodoList.Components;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddRazorComponents()
    .AddInteractiveServerComponents();

builder.Services.AddSingleton<TodoListService>();

var app = builder.Build();

if (!app.Environment.IsDevelopment())
{
    app.UseExceptionHandler("/Error", createScopeForErrors: true);
    app.UseHsts();
}

app.UseAntiforgery();

app.MapGet("/health", () => Results.Ok(new { status = "healthy", timestamp = DateTime.UtcNow }));

app.MapStaticAssets();
app.MapRazorComponents<App>()
    .AddInteractiveServerRenderMode();

var todoService = app.Services.GetRequiredService<TodoListService>();

var mcpBuilder = WebApplication.CreateBuilder();
mcpBuilder.WebHost.ConfigureKestrel(options => options.ListenAnyIP(5051));
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

mcpApp.MapGet("/mcp/", async (HttpContext context) => {
    context.Response.Headers["Content-Type"] = "text/event-stream";
    await context.Response.Body.FlushAsync();
    while (!context.RequestAborted.IsCancellationRequested)
    {
        await context.Response.WriteAsync(": keep-alive\n\n");
        await context.Response.Body.FlushAsync();
        await Task.Delay(10000, context.RequestAborted);
    }
});

mcpApp.MapPost("/mcp", async (HttpContext context) => {
    try {
        using var reader = new StreamReader(context.Request.Body);
        var requestBody = await reader.ReadToEndAsync();
        var jsonRequest = System.Text.Json.JsonDocument.Parse(requestBody);
        
        if (jsonRequest.RootElement.TryGetProperty("method", out var method) && 
            jsonRequest.RootElement.TryGetProperty("id", out var id))
        {
            var methodName = method.GetString();
            var responseId = id.GetInt32();
            
            object result = methodName switch
            {
                "initialize" => new {
                    serverInfo = new { name = "TodoList MCP Server", version = "1.0.0" },
                    capabilities = new { tools = new { listChanged = false } }
                },
                "tools/list" => new {
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
                },
                "tools/call" => HandleToolCall(),
                _ => new {}
            };

            object HandleToolCall()
            {
                var paramsElement = jsonRequest.RootElement.GetProperty("params");
                var toolName = paramsElement.GetProperty("name").GetString()!;
                var arguments = paramsElement.GetProperty("arguments");
                
                object toolResult = toolName switch
                {
                    "add_todo" => HandleAddTodo(),
                    "remove_todo" => HandleRemoveTodo(),
                    "mark_todo_done" => HandleMarkTodo(),
                    "get_todos" => HandleGetTodos(),
                    _ => new { success = false, message = $"Unknown tool: {toolName}" }
                };

                object HandleAddTodo()
                {
                    var title = arguments.GetProperty("title").GetString()!;
                    var isDone = arguments.TryGetProperty("isDone", out var isDoneProperty) ? isDoneProperty.GetBoolean() : false;
                    todoService.Add(new TodoItem { Title = title, IsDone = isDone });
                    return new { success = true, message = $"Added todo: {title}" };
                }

                object HandleRemoveTodo()
                {
                    var removeTitle = arguments.GetProperty("title").GetString()!;
                    todoService.Remove(removeTitle);
                    return new { success = true, message = $"Removed todo: {removeTitle}" };
                }

                object HandleMarkTodo()
                {
                    var markTitle = arguments.GetProperty("title").GetString()!;
                    var markDone = arguments.GetProperty("isDone").GetBoolean();
                    todoService.MarkAsDone(markTitle, markDone);
                    return new { success = true, message = $"Marked todo '{markTitle}' as {(markDone ? "done" : "not done")}" };
                }

                object HandleGetTodos()
                {
                    var allTodos = todoService.GetAll();
                    return new { 
                        success = true, 
                        todos = allTodos.Select(t => new { title = t.Title, isDone = t.IsDone }).ToArray(),
                        count = allTodos.Count
                    };
                }

                return new {
                    content = new[] {
                        new { type = "text", text = System.Text.Json.JsonSerializer.Serialize(toolResult) }
                    }
                };
            }
            
            var response = new { jsonrpc = "2.0", id = responseId, result };
            context.Response.ContentType = "application/json";
            await context.Response.WriteAsJsonAsync(response);
        }
    }
    catch (Exception ex)
    {
        var errorResponse = new {
            jsonrpc = "2.0",
            id = (int?)null,
            error = new { code = -32700, message = "Parse error", data = ex.Message }
        };
        
        context.Response.ContentType = "application/json";
        context.Response.StatusCode = 200;
        await context.Response.WriteAsJsonAsync(errorResponse);
    }
});

mcpApp.MapGet("/mcp/tools", async (HttpContext context) => {
    context.Response.ContentType = "application/json";    
    var tools = new object[] {
        new { name = "add", description = "Add a todo item", parameters = new[] { new { name = "title", type = "string", required = true }, new { name = "isDone", type = "boolean", required = false } } },
        new { name = "remove", description = "Remove a todo item by title", parameters = new[] { new { name = "title", type = "string", required = true } } },
        new { name = "markdone", description = "Mark a todo item as done or undone", parameters = new[] { new { name = "title", type = "string", required = true }, new { name = "isDone", type = "boolean", required = true } } },
        new { name = "get_todos", description = "Get the current list of all todo items", parameters = Array.Empty<object>() }
    };
    await context.Response.WriteAsJsonAsync(tools, context.RequestAborted);
});

_ = Task.Run(async () => await mcpApp.RunAsync());

app.Run();
