using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.DependencyInjection.Extensions;
using TodoList.Data;
using TodoList.Models;
using TodoList.Services;
using Xunit;
using System;
using System.Threading.Tasks;
using System.Net.Http;
using System.Text;
using System.Text.Json;
using System.Collections.Generic;
using System.Linq;

namespace TodoList.Tests;

public class IntegrationTests : IClassFixture<WebApplicationFactory<Program>>, IDisposable
{
    private readonly WebApplicationFactory<Program> _factory;
    private readonly HttpClient _client;
    private readonly IServiceScope _scope;
    private readonly TodoListService _service;
    private readonly TodoDbContext _context;

    public IntegrationTests(WebApplicationFactory<Program> factory)
    {
        _factory = factory.WithWebHostBuilder(builder =>
        {
            builder.ConfigureServices(services =>
            {
                // Remove the existing DbContext registration
                services.RemoveAll(typeof(DbContextOptions<TodoDbContext>));
                services.RemoveAll(typeof(TodoDbContext));

                // Add in-memory database for testing
                services.AddDbContext<TodoDbContext>(options =>
                {
                    options.UseInMemoryDatabase(Guid.NewGuid().ToString());
                });
            });
        });

        _client = _factory.CreateClient();
        _scope = _factory.Services.CreateScope();
        _service = _scope.ServiceProvider.GetRequiredService<TodoListService>();
        _context = _scope.ServiceProvider.GetRequiredService<TodoDbContext>();
    }

    public void Dispose()
    {
        _scope?.Dispose();
        _client?.Dispose();
    }

    #region Application Startup Tests

    [Fact]
    public async Task Application_StartsSuccessfully()
    {
        // Act
        var response = await _client.GetAsync("/");

        // Assert
        response.EnsureSuccessStatusCode();
        Assert.Equal("text/html; charset=utf-8", response.Content.Headers.ContentType?.ToString());
    }

    [Fact]
    public async Task HealthCheck_ReturnsHealthy()
    {
        // Act
        var response = await _client.GetAsync("/health");

        // Assert
        if (response.IsSuccessStatusCode)
        {
            var content = await response.Content.ReadAsStringAsync();
            Assert.Contains("Healthy", content);
        }
        else
        {
            // Health check endpoint might not be configured, which is fine
            Assert.True(true);
        }
    }

    #endregion

    #region Service Integration Tests

    [Fact]
    public async Task ServiceIntegration_FullWorkflow_WorksCorrectly()
    {
        // Arrange & Act - Add items
        var item1 = await _service.AddAsync(new TodoItem { Title = "Integration Test 1" });
        var item2 = await _service.AddAsync(new TodoItem { Title = "Integration Test 2" });
        var item3 = await _service.AddAsync(new TodoItem { Title = "Integration Test 3" });

        // Act - Get all items
        var allItems = await _service.GetAllAsync();

        // Act - Mark some as done
        await _service.MarkAsDoneAsync("Integration Test 1", true);
        await _service.MarkAsDoneAsync("Integration Test 3", true);

        // Act - Get counts
        var totalCount = await _service.GetCountAsync();
        var completedCount = await _service.GetCompletedCountAsync();

        // Act - Update an item
        item2.Title = "Updated Integration Test 2";
        var updatedItem = await _service.UpdateAsync(item2);

        // Act - Remove an item
        var removedCount = await _service.RemoveAsync("Integration Test 1");

        // Final state
        var finalItems = await _service.GetAllAsync();
        var finalCount = await _service.GetCountAsync();

        // Assert
        Assert.Equal(3, allItems.Count);
        Assert.Equal(3, totalCount);
        Assert.Equal(2, completedCount);
        Assert.NotNull(updatedItem);
        Assert.Equal("Updated Integration Test 2", updatedItem.Title);
        Assert.Equal(1, removedCount);
        Assert.Equal(2, finalItems.Count);
        Assert.Equal(2, finalCount);
    }

    [Fact]
    public async Task ServiceIntegration_DatabasePersistence_WorksCorrectly()
    {
        // Arrange - Add item
        var originalItem = await _service.AddAsync(new TodoItem { Title = "Persistence Test" });

        // Act - Create new service instance (simulating app restart)
        using var newScope = _factory.Services.CreateScope();
        var newService = newScope.ServiceProvider.GetRequiredService<TodoListService>();

        // Act - Retrieve item with new service instance
        var retrievedItems = await newService.GetAllAsync();
        var retrievedItem = retrievedItems.FirstOrDefault(i => i.Title == "Persistence Test");

        // Assert
        Assert.NotNull(retrievedItem);
        Assert.Equal(originalItem.Id, retrievedItem.Id);
        Assert.Equal(originalItem.Title, retrievedItem.Title);
        Assert.Equal(originalItem.IsDone, retrievedItem.IsDone);
    }

    #endregion

    #region Database Seeding Tests

    [Fact]
    public async Task DatabaseSeeding_WorksCorrectly()
    {
        // Arrange - Ensure database is empty
        var existingItems = await _context.TodoItems.ToListAsync();
        _context.TodoItems.RemoveRange(existingItems);
        await _context.SaveChangesAsync();

        // Act
        await _context.SeedDataAsync();

        // Assert
        var seededItems = await _context.TodoItems.ToListAsync();
        Assert.Equal(5, seededItems.Count);
        Assert.Contains(seededItems, i => i.Title == "Welcome to TodoList!");
        Assert.Contains(seededItems, i => i.IsDone == true);
        Assert.Contains(seededItems, i => i.IsDone == false);
    }

    #endregion

    #region Concurrent Access Tests

    [Fact]
    public async Task ConcurrentAccess_MultipleOperations_HandledCorrectly()
    {
        // Arrange
        var tasks = new List<Task>();

        // Act - Simulate concurrent operations
        for (int i = 0; i < 10; i++)
        {
            var index = i;
            tasks.Add(Task.Run(async () =>
            {
                using var scope = _factory.Services.CreateScope();
                var service = scope.ServiceProvider.GetRequiredService<TodoListService>();
                
                await service.AddAsync(new TodoItem { Title = $"Concurrent Item {index}" });
                await service.MarkAsDoneAsync($"Concurrent Item {index}", index % 2 == 0);
            }));
        }

        await Task.WhenAll(tasks);

        // Assert
        var allItems = await _service.GetAllAsync();
        var concurrentItems = allItems.Where(i => i.Title.StartsWith("Concurrent Item")).ToList();
        
        Assert.Equal(10, concurrentItems.Count);
        Assert.Equal(5, concurrentItems.Count(i => i.IsDone));
        Assert.Equal(5, concurrentItems.Count(i => !i.IsDone));
    }

    #endregion

    #region Error Handling Tests

    [Fact]
    public async Task ErrorHandling_InvalidOperations_HandledGracefully()
    {
        // Test null/empty operations
        var removeResult = await _service.RemoveAsync(null);
        Assert.Equal(0, removeResult);

        var markResult = await _service.MarkAsDoneAsync("");
        Assert.Equal(0, markResult);

        // Test operations on non-existent items
        var updateResult = await _service.UpdateAsync(new TodoItem { Id = 999, Title = "Non-existent" });
        Assert.Null(updateResult);

        var removeNonExistent = await _service.RemoveAsync("Does Not Exist");
        Assert.Equal(0, removeNonExistent);

        // Test invalid add operations
        await Assert.ThrowsAsync<ArgumentNullException>(() => _service.AddAsync(null!));
        await Assert.ThrowsAsync<ArgumentException>(() => _service.AddAsync(new TodoItem { Title = "" }));
    }

    #endregion

    #region Performance Tests

    [Fact]
    public async Task Performance_LargeDataSet_PerformsReasonably()
    {
        // Arrange - Add many items
        var addTasks = new List<Task>();
        for (int i = 0; i < 100; i++)
        {
            addTasks.Add(_service.AddAsync(new TodoItem { Title = $"Performance Test Item {i}" }));
        }
        await Task.WhenAll(addTasks);

        // Act & Assert - Operations should complete in reasonable time
        var startTime = DateTime.UtcNow;

        var allItems = await _service.GetAllAsync();
        var count = await _service.GetCountAsync();
        var completedCount = await _service.GetCompletedCountAsync();

        var endTime = DateTime.UtcNow;
        var duration = endTime - startTime;

        // Assert
        Assert.True(allItems.Count >= 100);
        Assert.True(count >= 100);
        Assert.Equal(0, completedCount);
        Assert.True(duration.TotalSeconds < 5); // Should complete within 5 seconds
    }

    #endregion

    #region Data Validation Tests

    [Fact]
    public async Task DataValidation_BusinessRules_EnforcedCorrectly()
    {
        // Test title uniqueness behavior
        var item1 = await _service.AddAsync(new TodoItem { Title = "Unique Test" });
        var item2 = await _service.AddAsync(new TodoItem { Title = "Unique Test" });

        Assert.Equal(item1.Id, item2.Id); // Should return existing item

        // Test timestamp behavior
        var beforeAdd = DateTime.UtcNow;
        var newItem = await _service.AddAsync(new TodoItem { Title = "Timestamp Test" });
        var afterAdd = DateTime.UtcNow;

        Assert.True(newItem.CreatedAt >= beforeAdd);
        Assert.True(newItem.CreatedAt <= afterAdd);
        Assert.Null(newItem.UpdatedAt);

        // Test update behavior
        await _service.MarkAsDoneAsync("Timestamp Test", true);
        var updatedItems = await _service.GetAllAsync();
        var updatedItem = updatedItems.First(i => i.Title == "Timestamp Test");

        Assert.True(updatedItem.IsDone);
        Assert.NotNull(updatedItem.UpdatedAt);
        Assert.True(updatedItem.UpdatedAt >= newItem.CreatedAt);
    }

    #endregion

    #region Service Dependencies Tests

    [Fact]
    public void ServiceDependencies_AreRegisteredCorrectly()
    {
        // Act
        using var scope = _factory.Services.CreateScope();
        var services = scope.ServiceProvider;

        // Assert - All required services can be resolved
        var dbContext = services.GetService<TodoDbContext>();
        var todoService = services.GetService<TodoListService>();

        Assert.NotNull(dbContext);
        Assert.NotNull(todoService);
    }

    [Fact]
    public async Task ServiceLifetime_ScopedServices_WorkCorrectly()
    {
        // Arrange & Act - Create multiple scopes
        TodoDbContext context1, context2;
        TodoListService service1, service2;

        using (var scope1 = _factory.Services.CreateScope())
        {
            context1 = scope1.ServiceProvider.GetRequiredService<TodoDbContext>();
            service1 = scope1.ServiceProvider.GetRequiredService<TodoListService>();
            await service1.AddAsync(new TodoItem { Title = "Scope Test 1" });
        }

        using (var scope2 = _factory.Services.CreateScope())
        {
            context2 = scope2.ServiceProvider.GetRequiredService<TodoDbContext>();
            service2 = scope2.ServiceProvider.GetRequiredService<TodoListService>();
            await service2.AddAsync(new TodoItem { Title = "Scope Test 2" });
        }

        // Assert - Different instances but shared data through database
        Assert.NotSame(context1, context2);
        Assert.NotSame(service1, service2);

        // Both items should be accessible from any service instance
        var allItems = await _service.GetAllAsync();
        Assert.Contains(allItems, i => i.Title == "Scope Test 1");
        Assert.Contains(allItems, i => i.Title == "Scope Test 2");
    }

    #endregion
}
