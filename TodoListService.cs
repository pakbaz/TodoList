using Microsoft.EntityFrameworkCore;

public class TodoListService
{
    private readonly IServiceScopeFactory _scopeFactory;
    
    public TodoListService(IServiceScopeFactory scopeFactory)
    {
        _scopeFactory = scopeFactory;
    }
    
    public async Task<IReadOnlyList<TodoItem>> GetAllAsync()
    {
        using var scope = _scopeFactory.CreateScope();
        var context = scope.ServiceProvider.GetRequiredService<TodoDbContext>();
        return await context.TodoItems.OrderBy(t => t.CreatedAt).ToListAsync();
    }
    
    public async Task AddAsync(TodoItem item)
    {
        if (string.IsNullOrWhiteSpace(item.Title))
            return;
            
        using var scope = _scopeFactory.CreateScope();
        var context = scope.ServiceProvider.GetRequiredService<TodoDbContext>();
        
        // Check if item with same title already exists
        var existingItem = await context.TodoItems.FirstOrDefaultAsync(t => t.Title == item.Title);
        if (existingItem != null)
            return;
            
        context.TodoItems.Add(item);
        await context.SaveChangesAsync();
    }
    
    public async Task RemoveAsync(string? title)
    {
        if (string.IsNullOrWhiteSpace(title))
            return;
            
        using var scope = _scopeFactory.CreateScope();
        var context = scope.ServiceProvider.GetRequiredService<TodoDbContext>();
        
        var itemsToRemove = await context.TodoItems.Where(t => t.Title == title).ToListAsync();
        if (itemsToRemove.Any())
        {
            context.TodoItems.RemoveRange(itemsToRemove);
            await context.SaveChangesAsync();
        }
    }
    
    public async Task MarkAsDoneAsync(string? title, bool isDone = true)
    {
        if (string.IsNullOrWhiteSpace(title))
            return;
            
        using var scope = _scopeFactory.CreateScope();
        var context = scope.ServiceProvider.GetRequiredService<TodoDbContext>();
        
        var todo = await context.TodoItems.FirstOrDefaultAsync(t => t.Title == title);
        if (todo != null)
        {
            todo.IsDone = isDone;
            await context.SaveChangesAsync();
        }
    }
    
    public async Task<int> GetCountAsync()
    {
        using var scope = _scopeFactory.CreateScope();
        var context = scope.ServiceProvider.GetRequiredService<TodoDbContext>();
        return await context.TodoItems.CountAsync();
    }
    
    public async Task UpdateAsync(TodoItem item)
    {
        if (item == null || string.IsNullOrWhiteSpace(item.Title))
            return;
            
        using var scope = _scopeFactory.CreateScope();
        var context = scope.ServiceProvider.GetRequiredService<TodoDbContext>();
        
        var existingItem = await context.TodoItems.FirstOrDefaultAsync(t => t.Id == item.Id);
        if (existingItem != null)
        {
            existingItem.Title = item.Title;
            existingItem.IsDone = item.IsDone;
            await context.SaveChangesAsync();
        }
    }
}
