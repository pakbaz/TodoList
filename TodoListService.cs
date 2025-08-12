using Microsoft.EntityFrameworkCore;
using TodoList.Data;
using TodoList.Models;

namespace TodoList.Services;

/// <summary>
/// Service for managing todo items with async operations and proper error handling.
/// </summary>
public class TodoListService
{
    private readonly TodoDbContext _context;
    private readonly ILogger<TodoListService> _logger;

    /// <summary>
    /// Initializes a new instance of the TodoListService.
    /// </summary>
    /// <param name="context">Database context (scoped).</param>
    /// <param name="logger">Logger for tracking operations and errors.</param>
    public TodoListService(TodoDbContext context, ILogger<TodoListService> logger)
    {
        _context = context ?? throw new ArgumentNullException(nameof(context));
        _logger = logger ?? throw new ArgumentNullException(nameof(logger));
    }

    /// <summary>
    /// Retrieves all todo items ordered by creation date.
    /// </summary>
    /// <param name="cancellationToken">Cancellation token.</param>
    /// <returns>A read-only list of all todo items.</returns>
    public async Task<IReadOnlyList<TodoItem>> GetAllAsync(CancellationToken cancellationToken = default)
    {
        try
        {
            var todos = await _context.TodoItems
                .OrderBy(t => t.CreatedAt)
                .AsNoTracking()
                .ToListAsync(cancellationToken);

            _logger.LogDebug("Retrieved {Count} todo items", todos.Count);
            return todos;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error retrieving todo items");
            throw;
        }
    }

    /// <summary>
    /// Adds a new todo item to the database.
    /// </summary>
    /// <param name="item">The todo item to add.</param>
    /// <param name="cancellationToken">Cancellation token.</param>
    /// <returns>The added todo item with generated ID.</returns>
    /// <exception cref="ArgumentNullException">Thrown when item is null.</exception>
    /// <exception cref="ArgumentException">Thrown when item title is empty.</exception>
    public async Task<TodoItem> AddAsync(TodoItem item, CancellationToken cancellationToken = default)
    {
        ArgumentNullException.ThrowIfNull(item);
        
        if (string.IsNullOrWhiteSpace(item.Title))
        {
            throw new ArgumentException("Todo item title cannot be empty.", nameof(item));
        }

        try
        {
            // Check if item with same title already exists
            var existingItem = await _context.TodoItems
                .FirstOrDefaultAsync(t => t.Title == item.Title, cancellationToken);
                
            if (existingItem != null)
            {
                _logger.LogWarning("Todo item with title '{Title}' already exists", item.Title);
                return existingItem;
            }

            // Set creation timestamp
            item.CreatedAt = DateTime.UtcNow;
            
            var entry = await _context.TodoItems.AddAsync(item, cancellationToken);
            await _context.SaveChangesAsync(cancellationToken);

            _logger.LogInformation("Added new todo item: {Title}", item.Title);
            return entry.Entity;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error adding todo item with title '{Title}'", item.Title);
            throw;
        }
    }

    /// <summary>
    /// Removes todo items with the specified title.
    /// </summary>
    /// <param name="title">The title of the todo items to remove.</param>
    /// <param name="cancellationToken">Cancellation token.</param>
    /// <returns>The number of items removed.</returns>
    public async Task<int> RemoveAsync(string? title, CancellationToken cancellationToken = default)
    {
        if (string.IsNullOrWhiteSpace(title))
        {
            _logger.LogWarning("Attempted to remove todo item with empty title");
            return 0;
        }

        try
        {
            var itemsToRemove = await _context.TodoItems
                .Where(t => t.Title == title)
                .ToListAsync(cancellationToken);

            if (itemsToRemove.Count == 0)
            {
                _logger.LogInformation("No todo items found with title '{Title}' to remove", title);
                return 0;
            }

            _context.TodoItems.RemoveRange(itemsToRemove);
            await _context.SaveChangesAsync(cancellationToken);

            _logger.LogInformation("Removed {Count} todo item(s) with title '{Title}'", itemsToRemove.Count, title);
            return itemsToRemove.Count;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error removing todo items with title '{Title}'", title);
            throw;
        }
    }

    /// <summary>
    /// Marks todo items with the specified title as done or undone.
    /// </summary>
    /// <param name="title">The title of the todo items to update.</param>
    /// <param name="isDone">The completion status to set.</param>
    /// <param name="cancellationToken">Cancellation token.</param>
    /// <returns>The number of items updated.</returns>
    public async Task<int> MarkAsDoneAsync(string? title, bool isDone = true, CancellationToken cancellationToken = default)
    {
        if (string.IsNullOrWhiteSpace(title))
        {
            _logger.LogWarning("Attempted to mark todo item as done with empty title");
            return 0;
        }

        try
        {
            var itemsToUpdate = await _context.TodoItems
                .Where(t => t.Title == title)
                .ToListAsync(cancellationToken);

            if (itemsToUpdate.Count == 0)
            {
                _logger.LogInformation("No todo items found with title '{Title}' to update", title);
                return 0;
            }

            foreach (var item in itemsToUpdate)
            {
                item.IsDone = isDone;
                item.Touch(); // Update the UpdatedAt timestamp
            }

            await _context.SaveChangesAsync(cancellationToken);

            _logger.LogInformation("Updated {Count} todo item(s) with title '{Title}' to {Status}", 
                itemsToUpdate.Count, title, isDone ? "completed" : "incomplete");
            return itemsToUpdate.Count;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error updating todo items with title '{Title}'", title);
            throw;
        }
    }

    /// <summary>
    /// Gets the total count of todo items.
    /// </summary>
    /// <param name="cancellationToken">Cancellation token.</param>
    /// <returns>The total number of todo items.</returns>
    public async Task<int> GetCountAsync(CancellationToken cancellationToken = default)
    {
        try
        {
            var count = await _context.TodoItems.CountAsync(cancellationToken);
            _logger.LogDebug("Total todo items count: {Count}", count);
            return count;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error getting todo items count");
            throw;
        }
    }

    /// <summary>
    /// Gets the count of completed todo items.
    /// </summary>
    /// <param name="cancellationToken">Cancellation token.</param>
    /// <returns>The number of completed todo items.</returns>
    public async Task<int> GetCompletedCountAsync(CancellationToken cancellationToken = default)
    {
        try
        {
            var count = await _context.TodoItems.CountAsync(t => t.IsDone, cancellationToken);
            _logger.LogDebug("Completed todo items count: {Count}", count);
            return count;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error getting completed todo items count");
            throw;
        }
    }

    /// <summary>
    /// Updates an existing todo item.
    /// </summary>
    /// <param name="item">The todo item to update.</param>
    /// <param name="cancellationToken">Cancellation token.</param>
    /// <returns>The updated todo item, or null if not found.</returns>
    /// <exception cref="ArgumentNullException">Thrown when item is null.</exception>
    /// <exception cref="ArgumentException">Thrown when item title is empty.</exception>
    public async Task<TodoItem?> UpdateAsync(TodoItem item, CancellationToken cancellationToken = default)
    {
        ArgumentNullException.ThrowIfNull(item);
        
        if (string.IsNullOrWhiteSpace(item.Title))
        {
            throw new ArgumentException("Todo item title cannot be empty.", nameof(item));
        }

        try
        {
            var existingItem = await _context.TodoItems
                .FirstOrDefaultAsync(t => t.Id == item.Id, cancellationToken);

            if (existingItem == null)
            {
                _logger.LogWarning("Todo item with ID {Id} not found for update", item.Id);
                return null;
            }

            existingItem.Title = item.Title;
            existingItem.IsDone = item.IsDone;
            existingItem.Touch();

            await _context.SaveChangesAsync(cancellationToken);

            _logger.LogInformation("Updated todo item with ID {Id}: {Title}", item.Id, item.Title);
            return existingItem;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error updating todo item with ID {Id}", item.Id);
            throw;
        }
    }
}
