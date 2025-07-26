using Microsoft.AspNetCore.Mvc;
using PerformanceBenchmark.Data;
using PerformanceBenchmark.Data.Models;

namespace PerformanceBenchmark.Api.Controllers;

[ApiController]
[Route("api/v1/[controller]")]
public class OrdersController : ControllerBase
{
    private readonly IOrderRepository _orderRepository;

    public OrdersController(IOrderRepository orderRepository)
    {
        _orderRepository = orderRepository;
    }

    [HttpGet]
    public async Task<ActionResult<object>> GetOrders([FromQuery] int limit = 10, [FromQuery] int offset = 0)
    {
        if (limit > 100) limit = 100;
        var orders = await _orderRepository.GetOrdersWithUsersAsync(limit, offset);
        return Ok(new { orders, limit, offset });
    }

    [HttpGet("{id}")]
    public async Task<ActionResult<Order>> GetOrder(Guid id)
    {
        var order = await _orderRepository.GetOrderByIdAsync(id);
        if (order == null)
        {
            return NotFound(new { error = "order not found" });
        }
        return Ok(order);
    }

    [HttpPost]
    public async Task<ActionResult<Order>> CreateOrder([FromBody] CreateOrderRequest request)
    {
        try
        {
            var order = await _orderRepository.CreateOrderAsync(request);
            return CreatedAtAction(nameof(GetOrder), new { id = order.Id }, order);
        }
        catch (Exception ex)
        {
            return BadRequest(new { error = ex.Message });
        }
    }
}