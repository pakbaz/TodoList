using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace TodoList.Models;

/// <summary>
/// Represents a todo item in the TodoList application.
/// </summary>
[Table("TodoItems")]
public class TodoItem
{
    /// <summary>
    /// Gets or sets the unique identifier for the todo item.
    /// </summary>
    [Key]
    [DatabaseGenerated(DatabaseGeneratedOption.Identity)]
    public int Id { get; set; }

    /// <summary>
    /// Gets or sets the title/description of the todo item.
    /// </summary>
    [Required]
    [StringLength(500, MinimumLength = 1, ErrorMessage = "Title must be between 1 and 500 characters.")]
    public string Title { get; set; } = string.Empty;

    /// <summary>
    /// Gets or sets a value indicating whether the todo item is completed.
    /// </summary>
    public bool IsDone { get; set; }

    /// <summary>
    /// Gets or sets the timestamp when the todo item was created.
    /// </summary>
    [DatabaseGenerated(DatabaseGeneratedOption.Identity)]
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;

    /// <summary>
    /// Gets or sets the timestamp when the todo item was last updated.
    /// </summary>
    public DateTime? UpdatedAt { get; set; }

    /// <summary>
    /// Updates the UpdatedAt timestamp to the current UTC time.
    /// </summary>
    public void Touch()
    {
        UpdatedAt = DateTime.UtcNow;
    }

    /// <summary>
    /// Returns a string representation of the todo item.
    /// </summary>
    /// <returns>A string containing the todo item details.</returns>
    public override string ToString()
    {
        return $"TodoItem {{ Id: {Id}, Title: \"{Title}\", IsDone: {IsDone}, CreatedAt: {CreatedAt:yyyy-MM-dd HH:mm:ss} }}";
    }

    /// <summary>
    /// Determines whether the specified object is equal to the current todo item.
    /// </summary>
    /// <param name="obj">The object to compare with the current todo item.</param>
    /// <returns>true if the specified object is equal to the current todo item; otherwise, false.</returns>
    public override bool Equals(object? obj)
    {
        return obj is TodoItem other && Id == other.Id;
    }

    /// <summary>
    /// Returns the hash code for this todo item.
    /// </summary>
    /// <returns>A hash code for the current todo item.</returns>
    public override int GetHashCode()
    {
        return Id.GetHashCode();
    }
}