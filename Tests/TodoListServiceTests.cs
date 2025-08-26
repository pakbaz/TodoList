using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Logging;
using TodoList.Data;
using TodoList.Models;
using TodoList.Services;
using Xunit;
using System.Threading.Tasks; // Added for Task recognition in async tests
using System; // For Guid
using System.Threading;
using System.Collections.Generic;

namespace TodoList.Tests;

public class TodoListServiceTests : IDisposable
{
    private readonly ServiceProvider _serviceProvider;
    private readonly TodoListService _service;
    private readonly TodoDbContext _context;

    public TodoListServiceTests()
    {
        var services = new ServiceCollection();
        services.AddLogging(builder => builder.AddConsole());
        services.AddDbContext<TodoDbContext>(opts => 
            opts.UseInMemoryDatabase(Guid.NewGuid().ToString()));
        services.AddScoped<TodoListService>();
        
        _serviceProvider = services.BuildServiceProvider();
        _service = _serviceProvider.GetRequiredService<TodoListService>();
        _context = _serviceProvider.GetRequiredService<TodoDbContext>();
    }

    public void Dispose()
    {
        _serviceProvider?.Dispose();
    }

    #region AddAsync Tests

    [Fact]
    public async Task AddAsync_ValidItem_ReturnsAddedItem()
    {
        // Arrange
        var item = new TodoItem { Title = "Test Task" };

        // Act
        var result = await _service.AddAsync(item);

        // Assert
        Assert.NotNull(result);
        Assert.Equal("Test Task", result.Title);
        Assert.False(result.IsDone);
        Assert.True(result.Id > 0);
        Assert.True(result.CreatedAt <= DateTime.UtcNow);
    }

    [Fact]
    public async Task AddAsync_DuplicateTitle_ReturnsExistingItem()
    {
        // Arrange
        var item1 = new TodoItem { Title = "Duplicate Task" };
        var item2 = new TodoItem { Title = "Duplicate Task" };

        // Act
        var result1 = await _service.AddAsync(item1);
        var result2 = await _service.AddAsync(item2);

        // Assert
        Assert.Equal(result1.Id, result2.Id);
        Assert.Equal(result1.Title, result2.Title);
    }

    [Fact]
    public async Task AddAsync_NullItem_ThrowsArgumentNullException()
    {
        // Act & Assert
        await Assert.ThrowsAsync<ArgumentNullException>(() => _service.AddAsync(null!));
    }

    [Fact]
    public async Task AddAsync_EmptyTitle_ThrowsArgumentException()
    {
        // Arrange
        var item = new TodoItem { Title = "" };

        // Act & Assert
        await Assert.ThrowsAsync<ArgumentException>(() => _service.AddAsync(item));
    }

    [Fact]
    public async Task AddAsync_WhitespaceTitle_ThrowsArgumentException()
    {
        // Arrange
        var item = new TodoItem { Title = "   " };

        // Act & Assert
        await Assert.ThrowsAsync<ArgumentException>(() => _service.AddAsync(item));
    }

    [Fact]
    public async Task AddAsync_WithCancellationToken_RespectsCancellation()
    {
        // Arrange
        var item = new TodoItem { Title = "Test Task" };
        using var cts = new CancellationTokenSource();
        cts.Cancel();

        // Act & Assert
        await Assert.ThrowsAsync<OperationCanceledException>(() => 
            _service.AddAsync(item, cts.Token));
    }

    #endregion

    #region GetAllAsync Tests

    [Fact]
    public async Task GetAllAsync_EmptyDatabase_ReturnsEmptyList()
    {
        // Act
        var result = await _service.GetAllAsync();

        // Assert
        Assert.NotNull(result);
        Assert.Empty(result);
    }

    [Fact]
    public async Task GetAllAsync_WithItems_ReturnsOrderedByCreatedAt()
    {
        // Arrange
        var item1 = new TodoItem { Title = "First Task" };
        var item2 = new TodoItem { Title = "Second Task" };
        
        await _service.AddAsync(item1);
        await Task.Delay(10); // Ensure different timestamps
        await _service.AddAsync(item2);

        // Act
        var result = await _service.GetAllAsync();

        // Assert
        Assert.Equal(2, result.Count);
        Assert.Equal("First Task", result[0].Title);
        Assert.Equal("Second Task", result[1].Title);
        Assert.True(result[0].CreatedAt <= result[1].CreatedAt);
    }

    [Fact]
    public async Task GetAllAsync_WithCancellationToken_RespectsCancellation()
    {
        // Arrange
        using var cts = new CancellationTokenSource();
        cts.Cancel();

        // Act & Assert
        await Assert.ThrowsAsync<OperationCanceledException>(() => 
            _service.GetAllAsync(cts.Token));
    }

    #endregion

    #region RemoveAsync Tests

    [Fact]
    public async Task RemoveAsync_ExistingItem_RemovesAndReturnsCount()
    {
        // Arrange
        await _service.AddAsync(new TodoItem { Title = "To Remove" });

        // Act
        var result = await _service.RemoveAsync("To Remove");

        // Assert
        Assert.Equal(1, result);
        var all = await _service.GetAllAsync();
        Assert.Empty(all);
    }

    [Fact]
    public async Task RemoveAsync_NonExistentItem_ReturnsZero()
    {
        // Act
        var result = await _service.RemoveAsync("Non-existent");

        // Assert
        Assert.Equal(0, result);
    }

    [Fact]
    public async Task RemoveAsync_EmptyTitle_ReturnsZero()
    {
        // Act
        var result = await _service.RemoveAsync("");

        // Assert
        Assert.Equal(0, result);
    }

    [Fact]
    public async Task RemoveAsync_NullTitle_ReturnsZero()
    {
        // Act
        var result = await _service.RemoveAsync(null);

        // Assert
        Assert.Equal(0, result);
    }

    [Fact]
    public async Task RemoveAsync_MultipleSameTitle_RemovesAll()
    {
        // Arrange
        await _context.TodoItems.AddAsync(new TodoItem { Title = "Duplicate", CreatedAt = DateTime.UtcNow });
        await _context.TodoItems.AddAsync(new TodoItem { Title = "Duplicate", CreatedAt = DateTime.UtcNow });
        await _context.SaveChangesAsync();

        // Act
        var result = await _service.RemoveAsync("Duplicate");

        // Assert
        Assert.Equal(2, result);
        var all = await _service.GetAllAsync();
        Assert.Empty(all);
    }

    #endregion

    #region MarkAsDoneAsync Tests

    [Fact]
    public async Task MarkAsDoneAsync_ExistingItem_UpdatesAndReturnsCount()
    {
        // Arrange
        await _service.AddAsync(new TodoItem { Title = "To Complete" });

        // Act
        var result = await _service.MarkAsDoneAsync("To Complete", true);

        // Assert
        Assert.Equal(1, result);
        var all = await _service.GetAllAsync();
        Assert.True(all[0].IsDone);
        Assert.NotNull(all[0].UpdatedAt);
    }

    [Fact]
    public async Task MarkAsDoneAsync_MarkAsUndone_UpdatesCorrectly()
    {
        // Arrange
        await _service.AddAsync(new TodoItem { Title = "Completed Task" });
        await _service.MarkAsDoneAsync("Completed Task", true);

        // Act
        var result = await _service.MarkAsDoneAsync("Completed Task", false);

        // Assert
        Assert.Equal(1, result);
        var all = await _service.GetAllAsync();
        Assert.False(all[0].IsDone);
    }

    [Fact]
    public async Task MarkAsDoneAsync_NonExistentItem_ReturnsZero()
    {
        // Act
        var result = await _service.MarkAsDoneAsync("Non-existent", true);

        // Assert
        Assert.Equal(0, result);
    }

    [Fact]
    public async Task MarkAsDoneAsync_EmptyTitle_ReturnsZero()
    {
        // Act
        var result = await _service.MarkAsDoneAsync("", true);

        // Assert
        Assert.Equal(0, result);
    }

    [Fact]
    public async Task MarkAsDoneAsync_DefaultParameter_MarkesAsDone()
    {
        // Arrange
        await _service.AddAsync(new TodoItem { Title = "Default Test" });

        // Act
        var result = await _service.MarkAsDoneAsync("Default Test");

        // Assert
        Assert.Equal(1, result);
        var all = await _service.GetAllAsync();
        Assert.True(all[0].IsDone);
    }

    #endregion

    #region GetCountAsync Tests

    [Fact]
    public async Task GetCountAsync_EmptyDatabase_ReturnsZero()
    {
        // Act
        var result = await _service.GetCountAsync();

        // Assert
        Assert.Equal(0, result);
    }

    [Fact]
    public async Task GetCountAsync_WithItems_ReturnsCorrectCount()
    {
        // Arrange
        await _service.AddAsync(new TodoItem { Title = "Item 1" });
        await _service.AddAsync(new TodoItem { Title = "Item 2" });
        await _service.AddAsync(new TodoItem { Title = "Item 3" });

        // Act
        var result = await _service.GetCountAsync();

        // Assert
        Assert.Equal(3, result);
    }

    #endregion

    #region GetCompletedCountAsync Tests

    [Fact]
    public async Task GetCompletedCountAsync_NoCompletedItems_ReturnsZero()
    {
        // Arrange
        await _service.AddAsync(new TodoItem { Title = "Incomplete" });

        // Act
        var result = await _service.GetCompletedCountAsync();

        // Assert
        Assert.Equal(0, result);
    }

    [Fact]
    public async Task GetCompletedCountAsync_WithCompletedItems_ReturnsCorrectCount()
    {
        // Arrange
        await _service.AddAsync(new TodoItem { Title = "Item 1" });
        await _service.AddAsync(new TodoItem { Title = "Item 2" });
        await _service.AddAsync(new TodoItem { Title = "Item 3" });
        
        await _service.MarkAsDoneAsync("Item 1", true);
        await _service.MarkAsDoneAsync("Item 3", true);

        // Act
        var result = await _service.GetCompletedCountAsync();

        // Assert
        Assert.Equal(2, result);
    }

    #endregion

    #region UpdateAsync Tests

    [Fact]
    public async Task UpdateAsync_ExistingItem_UpdatesAndReturnsItem()
    {
        // Arrange
        var added = await _service.AddAsync(new TodoItem { Title = "Original Title" });
        added.Title = "Updated Title";
        added.IsDone = true;

        // Act
        var result = await _service.UpdateAsync(added);

        // Assert
        Assert.NotNull(result);
        Assert.Equal("Updated Title", result.Title);
        Assert.True(result.IsDone);
        Assert.NotNull(result.UpdatedAt);
    }

    [Fact]
    public async Task UpdateAsync_NonExistentItem_ReturnsNull()
    {
        // Arrange
        var item = new TodoItem { Id = 999, Title = "Non-existent" };

        // Act
        var result = await _service.UpdateAsync(item);

        // Assert
        Assert.Null(result);
    }

    [Fact]
    public async Task UpdateAsync_NullItem_ThrowsArgumentNullException()
    {
        // Act & Assert
        await Assert.ThrowsAsync<ArgumentNullException>(() => _service.UpdateAsync(null!));
    }

    [Fact]
    public async Task UpdateAsync_EmptyTitle_ThrowsArgumentException()
    {
        // Arrange
        var item = new TodoItem { Id = 1, Title = "" };

        // Act & Assert
        await Assert.ThrowsAsync<ArgumentException>(() => _service.UpdateAsync(item));
    }

    [Fact]
    public async Task UpdateAsync_UpdatesTimestamp()
    {
        // Arrange
        var added = await _service.AddAsync(new TodoItem { Title = "Test" });
        var originalUpdatedAt = added.UpdatedAt;
        
        await Task.Delay(100); // Ensure different timestamp
        added.Title = "Updated";

        // Act
        var result = await _service.UpdateAsync(added);

        // Assert
        Assert.NotNull(result);
        Assert.NotEqual(originalUpdatedAt, result.UpdatedAt);
        Assert.NotNull(result.UpdatedAt);
    }

    #endregion

    #region Integration Tests

    [Fact]
    public async Task CompleteWorkflow_AddMarkDoneRemove_WorksCorrectly()
    {
        // Arrange & Act
        var added = await _service.AddAsync(new TodoItem { Title = "Workflow Test" });
        var totalCount = await _service.GetCountAsync();
        
        await _service.MarkAsDoneAsync("Workflow Test", true);
        var completedCount = await _service.GetCompletedCountAsync();
        
        var removed = await _service.RemoveAsync("Workflow Test");
        var finalCount = await _service.GetCountAsync();

        // Assert
        Assert.Equal("Workflow Test", added.Title);
        Assert.Equal(1, totalCount);
        Assert.Equal(1, completedCount);
        Assert.Equal(1, removed);
        Assert.Equal(0, finalCount);
    }

    [Fact]
    public async Task MultipleOperations_ConcurrentAccess_HandlesCorrectly()
    {
        // Arrange
        var tasks = new List<Task>();
        
        // Act - Add multiple items concurrently
        for (int i = 0; i < 10; i++)
        {
            var index = i;
            tasks.Add(_service.AddAsync(new TodoItem { Title = $"Concurrent Item {index}" }));
        }
        
        await Task.WhenAll(tasks);
        
        // Assert
        var count = await _service.GetCountAsync();
        Assert.Equal(10, count);
        
        var all = await _service.GetAllAsync();
        Assert.Equal(10, all.Count);
    }

    #endregion
}
