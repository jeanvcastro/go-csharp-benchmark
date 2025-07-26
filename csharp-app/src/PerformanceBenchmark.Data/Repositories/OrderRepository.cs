using Microsoft.EntityFrameworkCore;
using PerformanceBenchmark.Data.Models;

namespace PerformanceBenchmark.Data;

public class OrderRepository : IOrderRepository
{
    private readonly BenchmarkDbContext _context;

    public OrderRepository(BenchmarkDbContext context)
    {
        _context = context;
    }

    public async Task<List<Order>> GetOrdersWithUsersAsync(int limit, int offset)
    {
        return await _context.Orders
            .AsNoTracking()
            .Include(o => o.User)
            .OrderByDescending(o => o.CreatedAt)
            .Skip(offset)
            .Take(limit)
            .ToListAsync();
    }

    public async Task<Order?> GetOrderByIdAsync(Guid id)
    {
        return await _context.Orders
            .AsNoTracking()
            .Include(o => o.User)
            .Include(o => o.OrderItems)
            .FirstOrDefaultAsync(o => o.Id == id);
    }

    public async Task<Order> CreateOrderAsync(CreateOrderRequest request)
    {
        using var transaction = await _context.Database.BeginTransactionAsync();

        try
        {
            var orderNumber = $"ORD-{Guid.NewGuid().ToString()[..8]}";
            var totalAmount = request.OrderItems.Sum(item => item.UnitPrice * item.Quantity);

            var order = new Order
            {
                Id = Guid.NewGuid(),
                UserId = request.UserId,
                OrderNumber = orderNumber,
                TotalAmount = totalAmount,
                Status = "pending",
                CreatedAt = DateTime.UtcNow,
                UpdatedAt = DateTime.UtcNow
            };

            var orderItems = request.OrderItems.Select(item => new OrderItem
            {
                Id = Guid.NewGuid(),
                OrderId = order.Id,
                ProductName = item.ProductName,
                Quantity = item.Quantity,
                UnitPrice = item.UnitPrice,
                TotalPrice = item.UnitPrice * item.Quantity,
                CreatedAt = DateTime.UtcNow
            }).ToList();

            _context.Orders.Add(order);
            _context.OrderItems.AddRange(orderItems);
            await _context.SaveChangesAsync();
            await transaction.CommitAsync();

            return order;
        }
        catch
        {
            await transaction.RollbackAsync();
            throw;
        }
    }
}