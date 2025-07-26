INSERT INTO users (username, email, full_name) VALUES
('john_doe', 'john.doe@example.com', 'John Doe'),
('jane_smith', 'jane.smith@example.com', 'Jane Smith'),
('bob_wilson', 'bob.wilson@example.com', 'Bob Wilson'),
('alice_brown', 'alice.brown@example.com', 'Alice Brown'),
('charlie_davis', 'charlie.davis@example.com', 'Charlie Davis');

INSERT INTO orders (user_id, order_number, total_amount, status)
SELECT 
    u.id,
    'ORD-' || LPAD((ROW_NUMBER() OVER())::text, 6, '0'),
    (RANDOM() * 1000 + 50)::DECIMAL(10,2),
    CASE 
        WHEN RANDOM() < 0.7 THEN 'completed'
        WHEN RANDOM() < 0.9 THEN 'pending'
        ELSE 'cancelled'
    END
FROM users u
CROSS JOIN generate_series(1, 20) gs;

INSERT INTO order_items (order_id, product_name, quantity, unit_price, total_price)
SELECT 
    o.id,
    'Product ' || (RANDOM() * 100 + 1)::INTEGER,
    (RANDOM() * 5 + 1)::INTEGER,
    (RANDOM() * 50 + 10)::DECIMAL(10,2),
    ((RANDOM() * 5 + 1)::INTEGER * (RANDOM() * 50 + 10))::DECIMAL(10,2)
FROM orders o
CROSS JOIN generate_series(1, (RANDOM() * 3 + 1)::INTEGER) gs;