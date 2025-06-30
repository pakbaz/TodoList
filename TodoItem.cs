using System.ComponentModel.DataAnnotations;

public class TodoItem
{
    [Key]
    public int Id { get; set; }
    
    [Required]
    [MaxLength(500)]
    public string Title { get; set; } = string.Empty;
    
    public bool IsDone { get; set; }
    
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
}