-- =====================================================================
-- Online Food Delivery DBMS  |  01_schema.sql
-- Target: MySQL 8.0.16+  (CHECK constraints & window functions need 8.x)
-- =====================================================================

DROP DATABASE IF EXISTS food_delivery;
CREATE DATABASE food_delivery CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE food_delivery;

-- 1. CUSTOMERS ---------------------------------------------------------
CREATE TABLE customers (
    customer_id  INT AUTO_INCREMENT PRIMARY KEY,
    name         VARCHAR(100) NOT NULL,
    email        VARCHAR(120) NOT NULL UNIQUE,
    phone        CHAR(10)     NOT NULL UNIQUE,
    city         VARCHAR(50)  NOT NULL,
    created_at   DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT chk_customer_phone CHECK (phone REGEXP '^[0-9]{10}$')
) ENGINE=InnoDB;

-- 2. RESTAURANTS -------------------------------------------------------
CREATE TABLE restaurants (
    restaurant_id INT AUTO_INCREMENT PRIMARY KEY,
    name          VARCHAR(100) NOT NULL,
    city          VARCHAR(50)  NOT NULL,
    cuisine       VARCHAR(50)  NOT NULL,
    rating        DECIMAL(2,1) NOT NULL DEFAULT 0.0,
    CONSTRAINT chk_rating CHECK (rating BETWEEN 0 AND 5)
) ENGINE=InnoDB;

-- 3. MENU_ITEMS (1 restaurant -> many items) ---------------------------
CREATE TABLE menu_items (
    item_id        INT AUTO_INCREMENT PRIMARY KEY,
    restaurant_id  INT           NOT NULL,
    name           VARCHAR(100)  NOT NULL,
    category       VARCHAR(50)   NOT NULL,
    price          DECIMAL(8,2)  NOT NULL,
    is_available   BOOLEAN       NOT NULL DEFAULT TRUE,
    CONSTRAINT chk_price CHECK (price > 0),
    CONSTRAINT uq_item_per_restaurant UNIQUE (restaurant_id, name),
    CONSTRAINT fk_menu_restaurant FOREIGN KEY (restaurant_id)
        REFERENCES restaurants(restaurant_id) ON DELETE CASCADE
) ENGINE=InnoDB;

-- 4. DELIVERY_AGENTS ---------------------------------------------------
CREATE TABLE delivery_agents (
    agent_id      INT AUTO_INCREMENT PRIMARY KEY,
    name          VARCHAR(100) NOT NULL,
    phone         CHAR(10)     NOT NULL UNIQUE,
    vehicle_type  ENUM('Bike','Scooter','Bicycle') NOT NULL,
    city          VARCHAR(50)  NOT NULL
) ENGINE=InnoDB;

-- 5. ORDERS ------------------------------------------------------------
-- agent_id is NULL until an agent is assigned.
-- No total_amount column on purpose: it is derived data (see v_order_totals).
CREATE TABLE orders (
    order_id       INT AUTO_INCREMENT PRIMARY KEY,
    customer_id    INT         NOT NULL,
    restaurant_id  INT         NOT NULL,
    agent_id       INT         NULL,
    order_date     DATETIME    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    status         ENUM('Placed','Out for Delivery','Delivered','Cancelled')
                   NOT NULL DEFAULT 'Placed',
    CONSTRAINT fk_orders_customer   FOREIGN KEY (customer_id)
        REFERENCES customers(customer_id)       ON DELETE RESTRICT,
    CONSTRAINT fk_orders_restaurant FOREIGN KEY (restaurant_id)
        REFERENCES restaurants(restaurant_id)   ON DELETE RESTRICT,
    CONSTRAINT fk_orders_agent      FOREIGN KEY (agent_id)
        REFERENCES delivery_agents(agent_id)    ON DELETE SET NULL
) ENGINE=InnoDB;

-- 6. ORDER_ITEMS (resolves the M:N between orders and menu_items) ------
-- unit_price is a deliberate snapshot of the price AT ORDER TIME,
-- so later menu price changes do not rewrite history.
CREATE TABLE order_items (
    order_id    INT          NOT NULL,
    item_id     INT          NOT NULL,
    quantity    INT          NOT NULL,
    unit_price  DECIMAL(8,2) NOT NULL,
    PRIMARY KEY (order_id, item_id),
    CONSTRAINT chk_qty        CHECK (quantity > 0),
    CONSTRAINT chk_unit_price CHECK (unit_price > 0),
    CONSTRAINT fk_oi_order FOREIGN KEY (order_id)
        REFERENCES orders(order_id)     ON DELETE CASCADE,
    CONSTRAINT fk_oi_item  FOREIGN KEY (item_id)
        REFERENCES menu_items(item_id)  ON DELETE RESTRICT
) ENGINE=InnoDB;

-- 7. PAYMENTS (1 order -> at most 1 payment) ---------------------------
CREATE TABLE payments (
    payment_id      INT AUTO_INCREMENT PRIMARY KEY,
    order_id        INT           NOT NULL UNIQUE,
    method          ENUM('UPI','Card','COD') NOT NULL,
    amount          DECIMAL(10,2) NOT NULL,
    payment_status  ENUM('Pending','Success','Failed','Refunded') NOT NULL DEFAULT 'Pending',
    paid_at         DATETIME NULL,
    CONSTRAINT chk_pay_amount CHECK (amount > 0),
    CONSTRAINT fk_pay_order FOREIGN KEY (order_id)
        REFERENCES orders(order_id) ON DELETE CASCADE
) ENGINE=InnoDB;

-- INDEXES (foreign keys already get one; these speed up common queries) -
CREATE INDEX idx_orders_date    ON orders(order_date);
CREATE INDEX idx_orders_status  ON orders(status);
CREATE INDEX idx_customers_city ON customers(city);
CREATE INDEX idx_menu_category  ON menu_items(category);
