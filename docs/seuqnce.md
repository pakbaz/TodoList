sequenceDiagram
    participant User
    participant BlazorUI
    participant MCPAPI
    participant TodoListService
    participant TodoDbContext
    participant Database

    User->>BlazorUI: Interact (Add/Remove/Mark Todo)
    BlazorUI->>TodoListService: Request operation (async)
    TodoListService->>TodoDbContext: Query/Update (async)
    TodoDbContext->>Database: Execute SQL (async)
    Database-->>TodoDbContext: Return result
    TodoDbContext-->>TodoListService: Return entities
    TodoListService-->>BlazorUI: Return todos

    User->>MCPAPI: REST/MCP request (Add/Remove/Mark/Get)
    MCPAPI->>TodoListService: Request operation (async)
    TodoListService->>TodoDbContext: Query/Update (async)
    TodoDbContext->>Database: Execute SQL (async)
    Database-->>TodoDbContext: Return result
    TodoDbContext-->>TodoListService: Return entities
    TodoListService-->>MCPAPI: Return todos
    MCPAPI-->>User: Return response