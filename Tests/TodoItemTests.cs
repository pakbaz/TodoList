using System.ComponentModel.DataAnnotations;
using TodoList.Models;
using Xunit;
using System;
using System.Collections.Generic;
using System.Threading;
using System.Linq;

namespace TodoList.Tests;

public class TodoItemTests
{
    #region Constructor Tests

    [Fact]
    public void TodoItem_DefaultConstructor_InitializesCorrectly()
    {
        // Act
        var item = new TodoItem();

        // Assert
        Assert.Equal(0, item.Id);
        Assert.Equal(string.Empty, item.Title);
        Assert.False(item.IsDone);
        Assert.True(item.CreatedAt <= DateTime.UtcNow);
        Assert.Null(item.UpdatedAt);
    }

    #endregion

    #region Touch Method Tests

    [Fact]
    public void Touch_UpdatesTimestamp()
    {
        // Arrange
        var item = new TodoItem();
        var originalUpdatedAt = item.UpdatedAt;

        // Act
        item.Touch();

        // Assert
        Assert.NotEqual(originalUpdatedAt, item.UpdatedAt);
        Assert.NotNull(item.UpdatedAt);
        Assert.True(item.UpdatedAt <= DateTime.UtcNow);
    }

    [Fact]
    public void Touch_CalledMultipleTimes_UpdatesTimestamp()
    {
        // Arrange
        var item = new TodoItem();
        item.Touch();
        var firstTouch = item.UpdatedAt;

        // Wait a small amount to ensure different timestamp
        Thread.Sleep(1);

        // Act
        item.Touch();

        // Assert
        Assert.NotEqual(firstTouch, item.UpdatedAt);
        Assert.True(item.UpdatedAt >= firstTouch);
    }

    #endregion

    #region Property Tests

    [Fact]
    public void Title_CanBeSetAndRetrieved()
    {
        // Arrange
        var item = new TodoItem();
        const string title = "Test Title";

        // Act
        item.Title = title;

        // Assert
        Assert.Equal(title, item.Title);
    }

    [Fact]
    public void IsDone_CanBeSetAndRetrieved()
    {
        // Arrange
        var item = new TodoItem();

        // Act
        item.IsDone = true;

        // Assert
        Assert.True(item.IsDone);
    }

    [Fact]
    public void Id_CanBeSetAndRetrieved()
    {
        // Arrange
        var item = new TodoItem();
        const int id = 123;

        // Act
        item.Id = id;

        // Assert
        Assert.Equal(id, item.Id);
    }

    [Fact]
    public void CreatedAt_CanBeSetAndRetrieved()
    {
        // Arrange
        var item = new TodoItem();
        var dateTime = DateTime.UtcNow.AddDays(-1);

        // Act
        item.CreatedAt = dateTime;

        // Assert
        Assert.Equal(dateTime, item.CreatedAt);
    }

    [Fact]
    public void UpdatedAt_CanBeSetAndRetrieved()
    {
        // Arrange
        var item = new TodoItem();
        var dateTime = DateTime.UtcNow;

        // Act
        item.UpdatedAt = dateTime;

        // Assert
        Assert.Equal(dateTime, item.UpdatedAt);
    }

    #endregion

    #region Validation Tests

    [Theory]
    [InlineData("")]
    [InlineData(null)]
    public void TodoItem_WithInvalidTitle_FailsValidation(string title)
    {
        // Arrange
        var item = new TodoItem { Title = title! };
        var context = new ValidationContext(item);
        var results = new List<ValidationResult>();

        // Act
        var isValid = Validator.TryValidateObject(item, context, results, true);

        // Assert
        Assert.False(isValid);
        Assert.Contains(results, r => r.MemberNames.Contains(nameof(TodoItem.Title)));
    }

    [Fact]
    public void TodoItem_WithTooLongTitle_FailsValidation()
    {
        // Arrange
        var longTitle = new string('a', 501); // Exceeds 500 character limit
        var item = new TodoItem { Title = longTitle };
        var context = new ValidationContext(item);
        var results = new List<ValidationResult>();

        // Act
        var isValid = Validator.TryValidateObject(item, context, results, true);

        // Assert
        Assert.False(isValid);
        Assert.Contains(results, r => r.MemberNames.Contains(nameof(TodoItem.Title)));
    }

    [Fact]
    public void TodoItem_WithValidTitle_PassesValidation()
    {
        // Arrange
        var item = new TodoItem { Title = "Valid Title" };
        var context = new ValidationContext(item);
        var results = new List<ValidationResult>();

        // Act
        var isValid = Validator.TryValidateObject(item, context, results, true);

        // Assert
        Assert.True(isValid);
        Assert.Empty(results);
    }

    [Fact]
    public void TodoItem_WithMaxLengthTitle_PassesValidation()
    {
        // Arrange
        var maxTitle = new string('a', 500); // Exactly 500 characters
        var item = new TodoItem { Title = maxTitle };
        var context = new ValidationContext(item);
        var results = new List<ValidationResult>();

        // Act
        var isValid = Validator.TryValidateObject(item, context, results, true);

        // Assert
        Assert.True(isValid);
        Assert.Empty(results);
    }

    [Fact]
    public void TodoItem_WithMinLengthTitle_PassesValidation()
    {
        // Arrange
        var item = new TodoItem { Title = "a" }; // Exactly 1 character
        var context = new ValidationContext(item);
        var results = new List<ValidationResult>();

        // Act
        var isValid = Validator.TryValidateObject(item, context, results, true);

        // Assert
        Assert.True(isValid);
        Assert.Empty(results);
    }

    #endregion

    #region Business Logic Tests

    [Fact]
    public void TodoItem_CompletionWorkflow_WorksCorrectly()
    {
        // Arrange
        var item = new TodoItem { Title = "Complete me" };

        // Act - Mark as done
        item.IsDone = true;
        item.Touch();

        // Assert
        Assert.True(item.IsDone);
        Assert.NotNull(item.UpdatedAt);
        Assert.True(item.UpdatedAt <= DateTime.UtcNow);
    }

    [Fact]
    public void TodoItem_CreationTimestamp_IsReasonable()
    {
        // Arrange
        var beforeCreation = DateTime.UtcNow;

        // Act
        var item = new TodoItem { Title = "New Task" };

        // Assert
        var afterCreation = DateTime.UtcNow;
        Assert.True(item.CreatedAt >= beforeCreation);
        Assert.True(item.CreatedAt <= afterCreation);
    }

    #endregion
}
