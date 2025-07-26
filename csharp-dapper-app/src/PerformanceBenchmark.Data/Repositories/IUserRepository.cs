using PerformanceBenchmark.Data.Models;

namespace PerformanceBenchmark.Data;

public interface IUserRepository
{
    Task<List<User>> GetUsersAsync(int limit, int offset);
    Task<User?> GetUserByIdAsync(Guid id);
    Task<User> CreateUserAsync(CreateUserRequest request);
    Task<User?> UpdateUserAsync(Guid id, UpdateUserRequest request);
    Task<bool> DeleteUserAsync(Guid id);
}