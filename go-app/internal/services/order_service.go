package services

import (
	"context"
	"fmt"

	"benchmark-go/internal/database"
	"benchmark-go/internal/models"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
)

type OrderService struct{}

func NewOrderService() *OrderService {
	return &OrderService{}
}

func (s *OrderService) GetOrdersWithUsers(ctx context.Context, limit, offset int) ([]models.Order, error) {
	query := `
		SELECT 
			o.id, o.user_id, o.order_number, o.total_amount, o.status, o.created_at, o.updated_at,
			u.id, u.username, u.email, u.full_name, u.created_at, u.updated_at
		FROM orders o
		JOIN users u ON o.user_id = u.id
		ORDER BY o.created_at DESC
		LIMIT $1 OFFSET $2
	`

	rows, err := database.GetPool().Query(ctx, query, limit, offset)
	if err != nil {
		return nil, fmt.Errorf("failed to query orders: %w", err)
	}
	defer rows.Close()

	var orders []models.Order
	for rows.Next() {
		var order models.Order
		var user models.User

		err := rows.Scan(
			&order.ID, &order.UserID, &order.OrderNumber, &order.TotalAmount,
			&order.Status, &order.CreatedAt, &order.UpdatedAt,
			&user.ID, &user.Username, &user.Email, &user.FullName,
			&user.CreatedAt, &user.UpdatedAt,
		)
		if err != nil {
			return nil, fmt.Errorf("failed to scan order: %w", err)
		}

		order.User = &user
		orders = append(orders, order)
	}

	return orders, nil
}

func (s *OrderService) GetOrderByID(ctx context.Context, id uuid.UUID) (*models.Order, error) {
	query := `
		SELECT 
			o.id, o.user_id, o.order_number, o.total_amount, o.status, o.created_at, o.updated_at,
			u.id, u.username, u.email, u.full_name, u.created_at, u.updated_at
		FROM orders o
		JOIN users u ON o.user_id = u.id
		WHERE o.id = $1
	`

	var order models.Order
	var user models.User

	err := database.GetPool().QueryRow(ctx, query, id).Scan(
		&order.ID, &order.UserID, &order.OrderNumber, &order.TotalAmount,
		&order.Status, &order.CreatedAt, &order.UpdatedAt,
		&user.ID, &user.Username, &user.Email, &user.FullName,
		&user.CreatedAt, &user.UpdatedAt,
	)

	if err != nil {
		if err == pgx.ErrNoRows {
			return nil, nil
		}
		return nil, fmt.Errorf("failed to get order: %w", err)
	}

	order.User = &user

	orderItems, err := s.getOrderItems(ctx, order.ID)
	if err != nil {
		return nil, fmt.Errorf("failed to get order items: %w", err)
	}
	order.OrderItems = orderItems

	return &order, nil
}

func (s *OrderService) CreateOrder(ctx context.Context, req models.CreateOrderRequest) (*models.Order, error) {
	tx, err := database.GetPool().Begin(ctx)
	if err != nil {
		return nil, fmt.Errorf("failed to begin transaction: %w", err)
	}
	defer tx.Rollback(ctx)

	orderNumber := fmt.Sprintf("ORD-%s", uuid.New().String()[0:8])
	totalAmount := 0.0
	for _, item := range req.OrderItems {
		totalAmount += item.UnitPrice * float64(item.Quantity)
	}

	var order models.Order
	orderQuery := `
		INSERT INTO orders (user_id, order_number, total_amount, status) 
		VALUES ($1, $2, $3, 'pending') 
		RETURNING id, user_id, order_number, total_amount, status, created_at, updated_at
	`

	err = tx.QueryRow(ctx, orderQuery, req.UserID, orderNumber, totalAmount).Scan(
		&order.ID, &order.UserID, &order.OrderNumber, &order.TotalAmount,
		&order.Status, &order.CreatedAt, &order.UpdatedAt,
	)
	if err != nil {
		return nil, fmt.Errorf("failed to create order: %w", err)
	}

	itemQuery := `
		INSERT INTO order_items (order_id, product_name, quantity, unit_price, total_price)
		VALUES ($1, $2, $3, $4, $5)
	`

	for _, item := range req.OrderItems {
		totalPrice := item.UnitPrice * float64(item.Quantity)
		_, err = tx.Exec(ctx, itemQuery, order.ID, item.ProductName, item.Quantity, item.UnitPrice, totalPrice)
		if err != nil {
			return nil, fmt.Errorf("failed to create order item: %w", err)
		}
	}

	if err = tx.Commit(ctx); err != nil {
		return nil, fmt.Errorf("failed to commit transaction: %w", err)
	}

	return &order, nil
}

func (s *OrderService) getOrderItems(ctx context.Context, orderID uuid.UUID) ([]models.OrderItem, error) {
	query := `
		SELECT id, order_id, product_name, quantity, unit_price, total_price, created_at
		FROM order_items
		WHERE order_id = $1
		ORDER BY created_at
	`

	rows, err := database.GetPool().Query(ctx, query, orderID)
	if err != nil {
		return nil, fmt.Errorf("failed to query order items: %w", err)
	}
	defer rows.Close()

	var items []models.OrderItem
	for rows.Next() {
		var item models.OrderItem
		err := rows.Scan(
			&item.ID, &item.OrderID, &item.ProductName, &item.Quantity,
			&item.UnitPrice, &item.TotalPrice, &item.CreatedAt,
		)
		if err != nil {
			return nil, fmt.Errorf("failed to scan order item: %w", err)
		}
		items = append(items, item)
	}

	return items, nil
}