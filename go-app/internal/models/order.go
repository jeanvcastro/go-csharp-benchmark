package models

import (
	"time"

	"github.com/google/uuid"
)

type Order struct {
	ID           uuid.UUID   `json:"id" db:"id"`
	UserID       uuid.UUID   `json:"user_id" db:"user_id"`
	OrderNumber  string      `json:"order_number" db:"order_number"`
	TotalAmount  float64     `json:"total_amount" db:"total_amount"`
	Status       string      `json:"status" db:"status"`
	CreatedAt    time.Time   `json:"created_at" db:"created_at"`
	UpdatedAt    time.Time   `json:"updated_at" db:"updated_at"`
	User         *User       `json:"user,omitempty"`
	OrderItems   []OrderItem `json:"order_items,omitempty"`
}

type OrderItem struct {
	ID          uuid.UUID `json:"id" db:"id"`
	OrderID     uuid.UUID `json:"order_id" db:"order_id"`
	ProductName string    `json:"product_name" db:"product_name"`
	Quantity    int       `json:"quantity" db:"quantity"`
	UnitPrice   float64   `json:"unit_price" db:"unit_price"`
	TotalPrice  float64   `json:"total_price" db:"total_price"`
	CreatedAt   time.Time `json:"created_at" db:"created_at"`
}

type CreateOrderRequest struct {
	UserID     uuid.UUID           `json:"user_id" binding:"required"`
	OrderItems []CreateOrderItemRequest `json:"order_items" binding:"required,min=1"`
}

type CreateOrderItemRequest struct {
	ProductName string  `json:"product_name" binding:"required,min=1,max=255"`
	Quantity    int     `json:"quantity" binding:"required,min=1"`
	UnitPrice   float64 `json:"unit_price" binding:"required,gt=0"`
}