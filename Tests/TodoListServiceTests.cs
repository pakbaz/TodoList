using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Logging;
using TodoList.Data;
using TodoList.Models;
using TodoList.Services;
using Xunit;
using System.Threading.Tasks; // Added for Task recognition in async tests
using System; // For Guid

namespace TodoList.Tests;

public class TodoListServiceTests
{
    private TodoListService BuildService(out ServiceProvider sp)
    {
        var services = new ServiceCollection();
        services.AddLogging(builder => builder.AddConsole());
        services.AddDbContext<TodoDbContext>(opts => opts.UseInMemoryDatabase(Guid.NewGuid().ToString()));
        services.AddScoped<TodoListService>();
        sp = services.BuildServiceProvider();
        return sp.GetRequiredService<TodoListService>();
    }

    [Fact]
    public async Task AddAndRetrieveTodo()
    {
        var service = BuildService(out var sp);
        await service.AddAsync(new TodoItem { Title = "Test Task" });
        var all = await service.GetAllAsync();
        Assert.Single(all);
        Assert.Equal("Test Task", all[0].Title);
        await sp.DisposeAsync();
    }

    [Fact]
    public async Task MarkDoneAndCount()
    {
        var service = BuildService(out var sp);
        await service.AddAsync(new TodoItem { Title = "Item" });
        await service.MarkAsDoneAsync("Item", true);
        var completed = await service.GetCompletedCountAsync();
        Assert.Equal(1, completed);
        await sp.DisposeAsync();
    }
}
