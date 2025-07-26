package services

import (
	"context"
	"fmt"

	"benchmark-go/internal/database"
	"benchmark-go/internal/models"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
)

type UserService struct{}

func NewUserService() *UserService {
	return &UserService{}
}

func (s *UserService) GetUsers(ctx context.Context, limit, offset int) ([]models.User, error) {
	query := `
		SELECT id, username, email, full_name, created_at, updated_at 
		FROM users 
		ORDER BY created_at DESC 
		LIMIT $1 OFFSET $2
	`

	rows, err := database.GetPool().Query(ctx, query, limit, offset)
	if err != nil {
		return nil, fmt.Errorf("failed to query users: %w", err)
	}
	defer rows.Close()

	var users []models.User
	for rows.Next() {
		var user models.User
		err := rows.Scan(
			&user.ID, &user.Username, &user.Email, &user.FullName,
			&user.CreatedAt, &user.UpdatedAt,
		)
		if err != nil {
			return nil, fmt.Errorf("failed to scan user: %w", err)
		}
		users = append(users, user)
	}

	return users, nil
}

func (s *UserService) GetUserByID(ctx context.Context, id uuid.UUID) (*models.User, error) {
	query := `
		SELECT id, username, email, full_name, created_at, updated_at 
		FROM users 
		WHERE id = $1
	`

	var user models.User
	err := database.GetPool().QueryRow(ctx, query, id).Scan(
		&user.ID, &user.Username, &user.Email, &user.FullName,
		&user.CreatedAt, &user.UpdatedAt,
	)

	if err != nil {
		if err == pgx.ErrNoRows {
			return nil, nil
		}
		return nil, fmt.Errorf("failed to get user: %w", err)
	}

	return &user, nil
}

func (s *UserService) CreateUser(ctx context.Context, req models.CreateUserRequest) (*models.User, error) {
	query := `
		INSERT INTO users (username, email, full_name) 
		VALUES ($1, $2, $3) 
		RETURNING id, username, email, full_name, created_at, updated_at
	`

	var user models.User
	err := database.GetPool().QueryRow(ctx, query, req.Username, req.Email, req.FullName).Scan(
		&user.ID, &user.Username, &user.Email, &user.FullName,
		&user.CreatedAt, &user.UpdatedAt,
	)

	if err != nil {
		return nil, fmt.Errorf("failed to create user: %w", err)
	}

	return &user, nil
}

func (s *UserService) UpdateUser(ctx context.Context, id uuid.UUID, req models.UpdateUserRequest) (*models.User, error) {
	query := `
		UPDATE users 
		SET username = COALESCE(NULLIF($2, ''), username),
		    email = COALESCE(NULLIF($3, ''), email),
		    full_name = COALESCE(NULLIF($4, ''), full_name),
		    updated_at = NOW()
		WHERE id = $1
		RETURNING id, username, email, full_name, created_at, updated_at
	`

	var user models.User
	err := database.GetPool().QueryRow(ctx, query, id, req.Username, req.Email, req.FullName).Scan(
		&user.ID, &user.Username, &user.Email, &user.FullName,
		&user.CreatedAt, &user.UpdatedAt,
	)

	if err != nil {
		if err == pgx.ErrNoRows {
			return nil, nil
		}
		return nil, fmt.Errorf("failed to update user: %w", err)
	}

	return &user, nil
}

func (s *UserService) DeleteUser(ctx context.Context, id uuid.UUID) error {
	query := `DELETE FROM users WHERE id = $1`

	result, err := database.GetPool().Exec(ctx, query, id)
	if err != nil {
		return fmt.Errorf("failed to delete user: %w", err)
	}

	if result.RowsAffected() == 0 {
		return fmt.Errorf("user not found")
	}

	return nil
}