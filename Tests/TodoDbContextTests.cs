using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using TodoList.Data;
using TodoList.Models;
using Xunit;
using System;
using System.Threading.Tasks;
using System.Linq;

namespace TodoList.Tests;

public class TodoDbContextTests : IDisposable
{
    private readonly ServiceProvider _serviceProvider;
    private readonly TodoDbContext _context;

    public TodoDbContextTests()
    {
        var services = new ServiceCollection();
        services.AddDbContext<TodoDbContext>(options =>
            options.UseInMemoryDatabase(Guid.NewGuid().ToString()));

        _serviceProvider = services.BuildServiceProvider();
        _context = _serviceProvider.GetRequiredService<TodoDbContext>();
    }

    public void Dispose()
    {
        _context?.Dispose();
        _serviceProvider?.Dispose();
    }

    #region Configuration Tests

    [Fact]
    public void TodoDbContext_CanBeCreated()
    {
        // Assert
        Assert.NotNull(_context);
        Assert.NotNull(_context.TodoItems);
    }

    [Fact]
    public void TodoDbContext_HasCorrectDbSetProperty()
    {
        // Act
        var dbSet = _context.TodoItems;

        // Assert
        Assert.NotNull(dbSet);
        // Note: EF Core returns InternalDbSet<T> which implements DbSet<T>
        Assert.IsAssignableFrom<DbSet<TodoItem>>(dbSet);
    }

    #endregion

    #region Basic CRUD Operations

    [Fact]
    public async Task TodoDbContext_CanAddAndRetrieveItem()
    {
        // Arrange
        var item = new TodoItem 
        { 
            Title = "Test Item", 
            IsDone = false, 
            CreatedAt = DateTime.UtcNow 
        };

        // Act
        await _context.TodoItems.AddAsync(item);
        await _context.SaveChangesAsync();

        var retrieved = await _context.TodoItems.FirstOrDefaultAsync();

        // Assert
        Assert.NotNull(retrieved);
        Assert.Equal("Test Item", retrieved.Title);
        Assert.False(retrieved.IsDone);
        Assert.True(retrieved.Id > 0);
    }

    [Fact]
    public async Task TodoDbContext_CanUpdateItem()
    {
        // Arrange
        var item = new TodoItem 
        { 
            Title = "Original Title", 
            IsDone = false, 
            CreatedAt = DateTime.UtcNow 
        };

        await _context.TodoItems.AddAsync(item);
        await _context.SaveChangesAsync();

        // Act
        item.Title = "Updated Title";
        item.IsDone = true;
        item.Touch();

        await _context.SaveChangesAsync();

        var updated = await _context.TodoItems.FirstOrDefaultAsync();

        // Assert
        Assert.NotNull(updated);
        Assert.Equal("Updated Title", updated.Title);
        Assert.True(updated.IsDone);
        Assert.NotNull(updated.UpdatedAt);
    }

    [Fact]
    public async Task TodoDbContext_CanDeleteItem()
    {
        // Arrange
        var item = new TodoItem 
        { 
            Title = "To Delete", 
            IsDone = false, 
            CreatedAt = DateTime.UtcNow 
        };

        await _context.TodoItems.AddAsync(item);
        await _context.SaveChangesAsync();

        // Act
        _context.TodoItems.Remove(item);
        await _context.SaveChangesAsync();

        var count = await _context.TodoItems.CountAsync();

        // Assert
        Assert.Equal(0, count);
    }

    #endregion

    #region Model Configuration Tests

    [Fact]
    public async Task TodoDbContext_EnforcesRequiredTitle()
    {
        // Arrange
        var item = new TodoItem 
        { 
            Title = null!, // This should cause a validation error
            IsDone = false, 
            CreatedAt = DateTime.UtcNow 
        };

        // Act & Assert
        await _context.TodoItems.AddAsync(item);
        
        // Note: In-memory database doesn't enforce all constraints,
        // but we can test that the model is configured correctly
        var entityType = _context.Model.FindEntityType(typeof(TodoItem));
        var titleProperty = entityType?.FindProperty(nameof(TodoItem.Title));
        
        Assert.NotNull(titleProperty);
        Assert.False(titleProperty.IsNullable);
    }

    [Fact]
    public void TodoDbContext_ConfiguresTitleMaxLength()
    {
        // Act
        var entityType = _context.Model.FindEntityType(typeof(TodoItem));
        var titleProperty = entityType?.FindProperty(nameof(TodoItem.Title));

        // Assert
        Assert.NotNull(titleProperty);
        Assert.Equal(500, titleProperty.GetMaxLength());
    }

    [Fact]
    public void TodoDbContext_ConfiguresIndexes()
    {
        // Act
        var entityType = _context.Model.FindEntityType(typeof(TodoItem));
        var indexes = entityType?.GetIndexes().ToList();

        // Assert
        Assert.NotNull(indexes);
        Assert.NotEmpty(indexes);
        Assert.Contains(indexes, i => i.Properties.Any(p => p.Name == nameof(TodoItem.Title)));
        Assert.Contains(indexes, i => i.Properties.Any(p => p.Name == nameof(TodoItem.IsDone)));
        Assert.Contains(indexes, i => i.Properties.Any(p => p.Name == nameof(TodoItem.CreatedAt)));
    }

    [Fact]
    public void TodoDbContext_ConfiguresDefaultValues()
    {
        // Act
        var entityType = _context.Model.FindEntityType(typeof(TodoItem));
        var isDoneProperty = entityType?.FindProperty(nameof(TodoItem.IsDone));

        // Assert
        Assert.NotNull(isDoneProperty);
        Assert.Equal(false, isDoneProperty.GetDefaultValue());
    }

    #endregion

    #region SeedDataAsync Tests

    [Fact]
    public async Task SeedDataAsync_EmptyDatabase_AddsSampleData()
    {
        // Arrange
        var initialCount = await _context.TodoItems.CountAsync();
        Assert.Equal(0, initialCount);

        // Act
        await _context.SeedDataAsync();

        // Assert
        var count = await _context.TodoItems.CountAsync();
        Assert.True(count > 0);
        Assert.Equal(5, count); // Based on the seed data in the context

        var items = await _context.TodoItems.ToListAsync();
        Assert.Contains(items, i => i.Title == "Welcome to TodoList!");
        Assert.Contains(items, i => i.IsDone == true);
    }

    [Fact]
    public async Task SeedDataAsync_DatabaseWithData_DoesNotAddMore()
    {
        // Arrange
        await _context.TodoItems.AddAsync(new TodoItem 
        { 
            Title = "Existing Item", 
            CreatedAt = DateTime.UtcNow 
        });
        await _context.SaveChangesAsync();

        var initialCount = await _context.TodoItems.CountAsync();

        // Act
        await _context.SeedDataAsync();

        // Assert
        var finalCount = await _context.TodoItems.CountAsync();
        Assert.Equal(initialCount, finalCount);
    }

    [Fact]
    public async Task SeedDataAsync_CanBeCalledMultipleTimes()
    {
        // Act
        await _context.SeedDataAsync();
        var firstCallCount = await _context.TodoItems.CountAsync();

        await _context.SeedDataAsync();
        var secondCallCount = await _context.TodoItems.CountAsync();

        // Assert
        Assert.Equal(firstCallCount, secondCallCount);
    }

    #endregion

    #region Query Performance Tests

    [Fact]
    public async Task TodoDbContext_SupportsAsyncQueries()
    {
        // Arrange
        await SeedTestData();

        // Act
        var completedItems = await _context.TodoItems
            .Where(t => t.IsDone)
            .ToListAsync();

        var incompleteItems = await _context.TodoItems
            .Where(t => !t.IsDone)
            .CountAsync();

        // Assert
        Assert.NotEmpty(completedItems);
        Assert.True(incompleteItems > 0);
    }

    [Fact]
    public async Task TodoDbContext_SupportsComplexQueries()
    {
        // Arrange
        await SeedTestData();

        // Act
        var recentItems = await _context.TodoItems
            .Where(t => t.CreatedAt >= DateTime.UtcNow.AddDays(-1))
            .OrderByDescending(t => t.CreatedAt)
            .Take(3)
            .ToListAsync();

        // Assert
        Assert.NotEmpty(recentItems);
        Assert.True(recentItems.Count <= 3);
    }

    [Fact]
    public async Task TodoDbContext_SupportsGroupingQueries()
    {
        // Arrange
        await SeedTestData();

        // Act
        var statusGroups = await _context.TodoItems
            .GroupBy(t => t.IsDone)
            .Select(g => new { Status = g.Key, Count = g.Count() })
            .ToListAsync();

        // Assert
        Assert.NotEmpty(statusGroups);
        Assert.True(statusGroups.Count <= 2);
        Assert.Contains(statusGroups, g => g.Status == true || g.Status == false);
    }

    #endregion

    #region Helper Methods

    private async Task SeedTestData()
    {
        var items = new[]
        {
            new TodoItem { Title = "Test Item 1", IsDone = false, CreatedAt = DateTime.UtcNow.AddMinutes(-30) },
            new TodoItem { Title = "Test Item 2", IsDone = true, CreatedAt = DateTime.UtcNow.AddMinutes(-20) },
            new TodoItem { Title = "Test Item 3", IsDone = false, CreatedAt = DateTime.UtcNow.AddMinutes(-10) }
        };

        await _context.TodoItems.AddRangeAsync(items);
        await _context.SaveChangesAsync();
    }

    #endregion
}
