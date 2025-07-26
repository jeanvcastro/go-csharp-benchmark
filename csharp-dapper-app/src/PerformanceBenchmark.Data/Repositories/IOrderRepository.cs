using PerformanceBenchmark.Data.Models;

namespace PerformanceBenchmark.Data;

public interface IOrderRepository
{
    Task<List<Order>> GetOrdersWithUsersAsync(int limit, int offset);
    Task<Order?> GetOrderByIdAsync(Guid id);
    Task<Order> CreateOrderAsync(CreateOrderRequest request);
}