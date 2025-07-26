using Dapper;
using Microsoft.Extensions.Configuration;
using Npgsql;
using PerformanceBenchmark.Data.Models;

namespace PerformanceBenchmark.Data;

public class SqlUserRepository : IUserRepository
{
    private readonly string _connectionString;

    public SqlUserRepository(IConfiguration configuration)
    {
        _connectionString = configuration.GetConnectionString("DefaultConnection") 
                           ?? throw new InvalidOperationException("Connection string not found.");
    }

    public async Task<List<User>> GetUsersAsync(int limit, int offset)
    {
        const string query = @"
            SELECT id, username, email, full_name, created_at, updated_at 
            FROM users 
            ORDER BY created_at DESC 
            LIMIT @limit OFFSET @offset";

        using var connection = new NpgsqlConnection(_connectionString);
        var users = await connection.QueryAsync<User>(query, new { limit, offset });
        return users.ToList();
    }

    public async Task<User?> GetUserByIdAsync(Guid id)
    {
        const string query = @"
            SELECT id, username, email, full_name, created_at, updated_at 
            FROM users 
            WHERE id = @id";

        using var connection = new NpgsqlConnection(_connectionString);
        return await connection.QueryFirstOrDefaultAsync<User>(query, new { id });
    }

    public async Task<User> CreateUserAsync(CreateUserRequest request)
    {
        const string query = @"
            INSERT INTO users (username, email, full_name) 
            VALUES (@Username, @Email, @FullName) 
            RETURNING id, username, email, full_name, created_at, updated_at";

        using var connection = new NpgsqlConnection(_connectionString);
        return await connection.QuerySingleAsync<User>(query, request);
    }

    public async Task<User?> UpdateUserAsync(Guid id, UpdateUserRequest request)
    {
        const string query = @"
            UPDATE users 
            SET username = COALESCE(NULLIF(@Username, ''), username),
                email = COALESCE(NULLIF(@Email, ''), email),
                full_name = COALESCE(NULLIF(@FullName, ''), full_name),
                updated_at = NOW()
            WHERE id = @id
            RETURNING id, username, email, full_name, created_at, updated_at";

        using var connection = new NpgsqlConnection(_connectionString);
        return await connection.QueryFirstOrDefaultAsync<User>(query, new 
        { 
            id, 
            request.Username, 
            request.Email, 
            request.FullName 
        });
    }

    public async Task<bool> DeleteUserAsync(Guid id)
    {
        const string query = "DELETE FROM users WHERE id = @id";

        using var connection = new NpgsqlConnection(_connectionString);
        var rowsAffected = await connection.ExecuteAsync(query, new { id });
        return rowsAffected > 0;
    }
}