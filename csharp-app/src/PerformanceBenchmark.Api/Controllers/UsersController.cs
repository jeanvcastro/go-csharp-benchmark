using Microsoft.AspNetCore.Mvc;
using PerformanceBenchmark.Data;
using PerformanceBenchmark.Data.Models;

namespace PerformanceBenchmark.Api.Controllers;

[ApiController]
[Route("api/v1/[controller]")]
public class UsersController : ControllerBase
{
    private readonly IUserRepository _userRepository;

    public UsersController(IUserRepository userRepository)
    {
        _userRepository = userRepository;
    }

    [HttpGet]
    public async Task<ActionResult<object>> GetUsers([FromQuery] int limit = 10, [FromQuery] int offset = 0)
    {
        if (limit > 100) limit = 100;
        var users = await _userRepository.GetUsersAsync(limit, offset);
        return Ok(new { users, limit, offset });
    }

    [HttpGet("{id}")]
    public async Task<ActionResult<User>> GetUser(Guid id)
    {
        var user = await _userRepository.GetUserByIdAsync(id);
        if (user == null)
        {
            return NotFound(new { error = "user not found" });
        }
        return Ok(user);
    }

    [HttpPost]
    public async Task<ActionResult<User>> CreateUser([FromBody] CreateUserRequest request)
    {
        try
        {
            var user = await _userRepository.CreateUserAsync(request);
            return CreatedAtAction(nameof(GetUser), new { id = user.Id }, user);
        }
        catch (Exception ex)
        {
            return BadRequest(new { error = ex.Message });
        }
    }

    [HttpPut("{id}")]
    public async Task<ActionResult<User>> UpdateUser(Guid id, [FromBody] UpdateUserRequest request)
    {
        try
        {
            var user = await _userRepository.UpdateUserAsync(id, request);
            if (user == null)
            {
                return NotFound(new { error = "user not found" });
            }
            return Ok(user);
        }
        catch (Exception ex)
        {
            return BadRequest(new { error = ex.Message });
        }
    }

    [HttpDelete("{id}")]
    public async Task<ActionResult> DeleteUser(Guid id)
    {
        try
        {
            var deleted = await _userRepository.DeleteUserAsync(id);
            if (!deleted)
            {
                return NotFound(new { error = "user not found" });
            }
            return NoContent();
        }
        catch (Exception ex)
        {
            return BadRequest(new { error = ex.Message });
        }
    }
}