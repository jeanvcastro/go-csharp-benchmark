using Dapper;
using Microsoft.Extensions.Configuration;
using Npgsql;
using PerformanceBenchmark.Data.Models;

namespace PerformanceBenchmark.Data;

public class SqlOrderRepository : IOrderRepository
{
    private readonly string _connectionString;

    public SqlOrderRepository(IConfiguration configuration)
    {
        _connectionString = configuration.GetConnectionString("DefaultConnection") 
                           ?? throw new InvalidOperationException("Connection string not found.");
    }

    public async Task<List<Order>> GetOrdersWithUsersAsync(int limit, int offset)
    {
        const string query = @"
            SELECT 
                o.id, o.user_id, o.order_number, o.total_amount, o.status, o.created_at, o.updated_at,
                u.id, u.username, u.email, u.full_name, u.created_at, u.updated_at
            FROM orders o
            JOIN users u ON o.user_id = u.id
            ORDER BY o.created_at DESC
            LIMIT @limit OFFSET @offset";

        using var connection = new NpgsqlConnection(_connectionString);
        
        var orderDict = new Dictionary<Guid, Order>();
        
        await connection.QueryAsync<Order, User, Order>(
            query,
            (order, user) =>
            {
                if (!orderDict.TryGetValue(order.Id, out var existingOrder))
                {
                    existingOrder = order;
                    existingOrder.User = user;
                    orderDict.Add(order.Id, existingOrder);
                }
                return existingOrder;
            },
            new { limit, offset },
            splitOn: "id"
        );

        return orderDict.Values.ToList();
    }

    public async Task<Order?> GetOrderByIdAsync(Guid id)
    {
        const string orderQuery = @"
            SELECT 
                o.id, o.user_id, o.order_number, o.total_amount, o.status, o.created_at, o.updated_at,
                u.id, u.username, u.email, u.full_name, u.created_at, u.updated_at
            FROM orders o
            JOIN users u ON o.user_id = u.id
            WHERE o.id = @id";

        const string itemsQuery = @"
            SELECT id, order_id, product_name, quantity, unit_price, total_price, created_at
            FROM order_items
            WHERE order_id = @id
            ORDER BY created_at";

        using var connection = new NpgsqlConnection(_connectionString);
        
        var order = await connection.QueryAsync<Order, User, Order>(
            orderQuery,
            (o, u) =>
            {
                o.User = u;
                return o;
            },
            new { id },
            splitOn: "id"
        );

        var result = order.FirstOrDefault();
        if (result == null) return null;

        var orderItems = await connection.QueryAsync<OrderItem>(itemsQuery, new { id });
        result.OrderItems = orderItems.ToList();

        return result;
    }

    public async Task<Order> CreateOrderAsync(CreateOrderRequest request)
    {
        using var connection = new NpgsqlConnection(_connectionString);
        using var transaction = await connection.BeginTransactionAsync();

        try
        {
            var orderNumber = $"ORD-{Guid.NewGuid().ToString()[..8]}";
            var totalAmount = request.OrderItems.Sum(item => item.UnitPrice * item.Quantity);

            const string orderQuery = @"
                INSERT INTO orders (user_id, order_number, total_amount, status) 
                VALUES (@UserID, @orderNumber, @totalAmount, 'pending') 
                RETURNING id, user_id, order_number, total_amount, status, created_at, updated_at";

            var order = await connection.QuerySingleAsync<Order>(
                orderQuery, 
                new { request.UserId, orderNumber, totalAmount }, 
                transaction
            );

            const string itemQuery = @"
                INSERT INTO order_items (order_id, product_name, quantity, unit_price, total_price)
                VALUES (@OrderId, @ProductName, @Quantity, @UnitPrice, @TotalPrice)";

            foreach (var item in request.OrderItems)
            {
                var totalPrice = item.UnitPrice * item.Quantity;
                await connection.ExecuteAsync(
                    itemQuery,
                    new 
                    { 
                        OrderId = order.Id, 
                        item.ProductName, 
                        item.Quantity, 
                        item.UnitPrice, 
                        TotalPrice = totalPrice 
                    },
                    transaction
                );
            }

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