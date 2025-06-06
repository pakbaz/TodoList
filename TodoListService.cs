public class TodoListService
{
    private readonly List<TodoItem> _todos = new();
    
    public IReadOnlyList<TodoItem> GetAll() => _todos.AsReadOnly();
    
    public void Add(TodoItem item)
    {
        if (!string.IsNullOrWhiteSpace(item.Title) && !_todos.Exists(t => t.Title == item.Title))
            _todos.Add(item);
    }
    
    public void Remove(string? title)
    {
        _todos.RemoveAll(t => t.Title == title);
    }
    
    public void MarkAsDone(string? title, bool isDone = true)
    {
        var todo = _todos.FirstOrDefault(t => t.Title == title);
        if (todo != null)
        {
            todo.IsDone = isDone;
        }
    }
}
