using PerformanceBenchmark.Data.Models;

namespace PerformanceBenchmark.Data;

public class OrderService
{
    private readonly IOrderRepository _orderRepository;

    public OrderService(IOrderRepository orderRepository)
    {
        _orderRepository = orderRepository;
    }

    public async Task<List<Order>> GetOrdersAsync(int limit = 10, int offset = 0)
    {
        if (limit > 100) limit = 100;
        return await _orderRepository.GetOrdersWithUsersAsync(limit, offset);
    }

    public async Task<Order?> GetOrderByIdAsync(Guid id)
    {
        return await _orderRepository.GetOrderByIdAsync(id);
    }

    public async Task<Order> CreateOrderAsync(CreateOrderRequest request)
    {
        return await _orderRepository.CreateOrderAsync(request);
    }
}