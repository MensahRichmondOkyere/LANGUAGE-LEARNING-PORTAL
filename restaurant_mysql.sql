-- Filename: restaurant_mysql.sql
-- MySQL 8+
CREATE DATABASE IF NOT EXISTS restaurant_mysql CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci;
USE restaurant_mysql;

-- Customers
CREATE TABLE IF NOT EXISTS customers (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  name VARCHAR(200) NOT NULL,
  phone VARCHAR(20) NOT NULL,
  email VARCHAR(255),
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id)
) ENGINE=InnoDB;

-- Menu items
CREATE TABLE IF NOT EXISTS menu_items (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  name VARCHAR(255) NOT NULL,
  category ENUM('APPETIZER','MAIN','DESSERT','DRINK') NOT NULL,
  price_cents INT UNSIGNED NOT NULL,
  available BOOLEAN NOT NULL DEFAULT TRUE,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id)
) ENGINE=InnoDB;

-- Reservations
CREATE TABLE IF NOT EXISTS reservations (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  customer_id BIGINT UNSIGNED NOT NULL,
  reserved_at DATETIME NOT NULL,
  party_size INT NOT NULL,
  status ENUM('BOOKED','SEATED','CANCELLED','COMPLETED') NOT NULL DEFAULT 'BOOKED',
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  KEY ix_res_customer_time (customer_id, reserved_at),
  CONSTRAINT fk_res_customer FOREIGN KEY (customer_id) REFERENCES customers(id)
    ON UPDATE CASCADE ON DELETE RESTRICT
) ENGINE=InnoDB;

-- Orders
CREATE TABLE IF NOT EXISTS orders (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  customer_id BIGINT UNSIGNED NOT NULL,
  table_number INT,
  status ENUM('OPEN','PAID','CANCELLED') NOT NULL DEFAULT 'OPEN',
  subtotal_cents INT UNSIGNED NOT NULL DEFAULT 0,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  KEY ix_orders_customer_created (customer_id, created_at),
  CONSTRAINT fk_order_customer FOREIGN KEY (customer_id) REFERENCES customers(id)
    ON UPDATE CASCADE ON DELETE RESTRICT
) ENGINE=InnoDB;

-- Order items
CREATE TABLE IF NOT EXISTS order_items (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  order_id BIGINT UNSIGNED NOT NULL,
  menu_item_id BIGINT UNSIGNED NOT NULL,
  qty INT NOT NULL,
  unit_price_cents INT UNSIGNED NOT NULL,
  PRIMARY KEY (id),
  UNIQUE KEY ux_order_menu (order_id, menu_item_id),
  KEY ix_order_items_menu (menu_item_id),
  CONSTRAINT fk_orderitems_order FOREIGN KEY (order_id) REFERENCES orders(id)
    ON UPDATE CASCADE ON DELETE CASCADE,
  CONSTRAINT fk_orderitems_menu FOREIGN KEY (menu_item_id) REFERENCES menu_items(id)
    ON UPDATE CASCADE ON DELETE RESTRICT
) ENGINE=InnoDB;

-- Trigger to maintain order subtotal
DELIMITER $$
CREATE TRIGGER trg_order_items_after_change
AFTER INSERT ON order_items FOR EACH ROW
BEGIN
  UPDATE orders SET subtotal_cents = (
    SELECT COALESCE(SUM(qty * unit_price_cents),0)
    FROM order_items WHERE order_id = NEW.order_id
  ) WHERE id = NEW.order_id;
END $$
DELIMITER ;

-- Seed data
INSERT INTO customers (name, phone, email) VALUES
  ('Alice Johnson','555-1234','alice@example.com'),
  ('Bob Smith','555-5678','bob@example.com');

INSERT INTO menu_items (name, category, price_cents, available) VALUES
  ('Caesar Salad','APPETIZER', 800, TRUE),
  ('Grilled Salmon','MAIN', 2200, TRUE),
  ('Cheesecake','DESSERT', 1200, TRUE),
  ('Lemonade','DRINK', 500, TRUE);

INSERT INTO reservations (customer_id, reserved_at, party_size, status)
VALUES (1, '2025-08-22 19:00:00', 2, 'BOOKED');

INSERT INTO orders (customer_id, table_number, status) VALUES (1, 5, 'OPEN');
INSERT INTO order_items (order_id, menu_item_id, qty, unit_price_cents)
VALUES (1, 2, 1, 2200), (1, 4, 1, 500);

-- Example queries
-- Tonight's reservations
SELECT r.id, c.name, r.reserved_at, r.party_size, r.status
FROM reservations r
JOIN customers c ON c.id = r.customer_id
WHERE DATE(r.reserved_at) = CURDATE();

-- Revenue by category
SELECT mi.category, SUM(oi.qty * oi.unit_price_cents) AS revenue_cents
FROM order_items oi
JOIN menu_items mi ON mi.id = oi.menu_item_id
GROUP BY mi.category
ORDER BY revenue_cents DESC;
