using System.Text.Json.Serialization;

namespace PerformanceBenchmark.Data.Models;

public class Order
{
    public Guid Id { get; set; }
    public Guid UserId { get; set; }
    public string OrderNumber { get; set; } = string.Empty;
    public decimal TotalAmount { get; set; }
    public string Status { get; set; } = string.Empty;
    public DateTime CreatedAt { get; set; }
    public DateTime UpdatedAt { get; set; }
    
    public User User { get; set; } = null!;
    public ICollection<OrderItem> OrderItems { get; set; } = new List<OrderItem>();
}

public class OrderItem
{
    public Guid Id { get; set; }
    public Guid OrderId { get; set; }
    public string ProductName { get; set; } = string.Empty;
    public int Quantity { get; set; }
    public decimal UnitPrice { get; set; }
    public decimal TotalPrice { get; set; }
    public DateTime CreatedAt { get; set; }
    
    [JsonIgnore]
    public Order Order { get; set; } = null!;
}

public class CreateOrderRequest
{
    [JsonPropertyName("user_id")]
    public Guid UserId { get; set; }
    
    [JsonPropertyName("order_items")]
    public List<CreateOrderItemRequest> OrderItems { get; set; } = new();
}

public class CreateOrderItemRequest
{
    [JsonPropertyName("product_name")]
    public string ProductName { get; set; } = string.Empty;
    
    [JsonPropertyName("quantity")]
    public int Quantity { get; set; }
    
    [JsonPropertyName("unit_price")]
    public decimal UnitPrice { get; set; }
}