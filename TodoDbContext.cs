using Microsoft.EntityFrameworkCore;
using TodoList.Models;

namespace TodoList.Data;

/// <summary>
/// Entity Framework Core database context for the TodoList application.
/// Provides access to TodoItem entities and handles database configuration.
/// </summary>
public class TodoDbContext : DbContext
{
    /// <summary>
    /// Initializes a new instance of the TodoDbContext.
    /// </summary>
    /// <param name="options">Database context options.</param>
    public TodoDbContext(DbContextOptions<TodoDbContext> options) : base(options)
    {
    }

    /// <summary>
    /// Gets or sets the TodoItems DbSet for managing todo items.
    /// </summary>
    public DbSet<TodoItem> TodoItems => Set<TodoItem>();

    /// <summary>
    /// Configures the entity model and database schema.
    /// </summary>
    /// <param name="modelBuilder">The model builder instance.</param>
    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        ArgumentNullException.ThrowIfNull(modelBuilder);
        
        base.OnModelCreating(modelBuilder);

        // Configure TodoItem entity
        modelBuilder.Entity<TodoItem>(entity =>
        {
            // Primary key
            entity.HasKey(e => e.Id);
            
            // Properties
            entity.Property(e => e.Title)
                .IsRequired()
                .HasMaxLength(500)
                .HasComment("The title/description of the todo item");
                
            entity.Property(e => e.IsDone)
                .HasDefaultValue(false)
                .HasComment("Indicates whether the todo item is completed");
                
            entity.Property(e => e.CreatedAt)
                .HasDefaultValueSql("CURRENT_TIMESTAMP")
                .HasComment("Timestamp when the todo item was created");
            
            // Indexes for performance
            entity.HasIndex(e => e.Title)
                .HasDatabaseName("IX_TodoItems_Title");
                
            entity.HasIndex(e => e.IsDone)
                .HasDatabaseName("IX_TodoItems_IsDone");
                
            entity.HasIndex(e => e.CreatedAt)
                .HasDatabaseName("IX_TodoItems_CreatedAt");
        });
    }

    /// <summary>
    /// Seeds the database with initial data if it's empty.
    /// </summary>
    /// <param name="cancellationToken">Cancellation token.</param>
    /// <returns>A task representing the async operation.</returns>
    public async Task SeedDataAsync(CancellationToken cancellationToken = default)
    {
        if (await TodoItems.AnyAsync(cancellationToken))
        {
            return; // Database already has data
        }

        var sampleTodos = new[]
        {
            new TodoItem { Title = "Welcome to TodoList!", IsDone = false },
            new TodoItem { Title = "Try adding a new todo item", IsDone = false },
            new TodoItem { Title = "Mark items as complete when done", IsDone = false },
            new TodoItem { Title = "Test the MCP API integration", IsDone = false },
            new TodoItem { Title = "This is a completed sample", IsDone = true }
        };

        await TodoItems.AddRangeAsync(sampleTodos, cancellationToken);
        await SaveChangesAsync(cancellationToken);
    }
}
