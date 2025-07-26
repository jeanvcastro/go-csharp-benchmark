using PerformanceBenchmark.Data.Models;

namespace PerformanceBenchmark.Data;

public class UserService
{
    private readonly IUserRepository _userRepository;

    public UserService(IUserRepository userRepository)
    {
        _userRepository = userRepository;
    }

    public async Task<List<User>> GetUsersAsync(int limit = 10, int offset = 0)
    {
        if (limit > 100) limit = 100;
        return await _userRepository.GetUsersAsync(limit, offset);
    }

    public async Task<User?> GetUserByIdAsync(Guid id)
    {
        return await _userRepository.GetUserByIdAsync(id);
    }

    public async Task<User> CreateUserAsync(CreateUserRequest request)
    {
        return await _userRepository.CreateUserAsync(request);
    }

    public async Task<User?> UpdateUserAsync(Guid id, UpdateUserRequest request)
    {
        return await _userRepository.UpdateUserAsync(id, request);
    }

    public async Task<bool> DeleteUserAsync(Guid id)
    {
        return await _userRepository.DeleteUserAsync(id);
    }
}