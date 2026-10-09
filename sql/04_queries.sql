
USE food_delivery;

-- Q1. Customers living in Indore                          [SELECT + WHERE]
SELECT customer_id, name, email
FROM customers
WHERE city = 'Indore';

-- Q2. Menu of 'Spice Garden', costliest first             [JOIN + ORDER BY]
SELECT r.name AS restaurant, m.name AS item, m.category, m.price
FROM menu_items m
JOIN restaurants r ON r.restaurant_id = m.restaurant_id
WHERE r.name = 'Spice Garden'
ORDER BY m.price DESC;

-- Q3. Every order with customer, restaurant, agent        [multi-table JOIN]
--     LEFT JOIN keeps orders that have no agent yet.
SELECT o.order_id, c.name AS customer, r.name AS restaurant,
       a.name AS agent, o.status
FROM orders o
JOIN customers   c ON c.customer_id   = o.customer_id
JOIN restaurants r ON r.restaurant_id = o.restaurant_id
LEFT JOIN delivery_agents a ON a.agent_id = o.agent_id
ORDER BY o.order_id;

-- Q4. Total amount of each order                          [GROUP BY + SUM]
SELECT order_id, SUM(quantity * unit_price) AS order_total
FROM order_items
GROUP BY order_id
ORDER BY order_id;

-- Q5. Revenue per restaurant (delivered orders only)      [GROUP BY + JOIN]
SELECT r.name AS restaurant,
       COUNT(DISTINCT o.order_id)       AS delivered_orders,
       SUM(oi.quantity * oi.unit_price) AS revenue
FROM restaurants r
JOIN orders      o  ON o.restaurant_id = r.restaurant_id
JOIN order_items oi ON oi.order_id     = o.order_id
WHERE o.status = 'Delivered'
GROUP BY r.restaurant_id, r.name
ORDER BY revenue DESC;

-- Q6. Top 3 customers by money spent (delivered orders)   [LIMIT]
SELECT c.name, SUM(oi.quantity * oi.unit_price) AS total_spent
FROM customers c
JOIN orders      o  ON o.customer_id = c.customer_id
JOIN order_items oi ON oi.order_id   = o.order_id
WHERE o.status = 'Delivered'
GROUP BY c.customer_id, c.name
ORDER BY total_spent DESC
LIMIT 3;

-- Q7. Customers who have never placed an order            [LEFT JOIN ... IS NULL]
SELECT c.customer_id, c.name
FROM customers c
LEFT JOIN orders o ON o.customer_id = c.customer_id
WHERE o.order_id IS NULL;

-- Q8. Menu items that have never been ordered             [NOT EXISTS]
SELECT m.item_id, m.name
FROM menu_items m
WHERE NOT EXISTS (SELECT 1 FROM order_items oi WHERE oi.item_id = m.item_id);

-- Q9. Most popular items by total quantity sold           [GROUP BY + ORDER BY]
SELECT m.name, SUM(oi.quantity) AS units_sold
FROM menu_items m
JOIN order_items oi ON oi.item_id = m.item_id
GROUP BY m.item_id, m.name
ORDER BY units_sold DESC
LIMIT 5;

-- Q10. Orders costing more than the average order         [subquery on a view]
SELECT order_id, total_amount
FROM v_order_totals
WHERE total_amount > (SELECT AVG(total_amount) FROM v_order_totals)
ORDER BY total_amount DESC;

-- Q11. Deliveries handled by each agent (0 included)      [LEFT JOIN + COUNT]
SELECT a.name, a.city, COUNT(o.order_id) AS deliveries
FROM delivery_agents a
LEFT JOIN orders o ON o.agent_id = a.agent_id
                  AND o.status   = 'Delivered'
GROUP BY a.agent_id, a.name, a.city
ORDER BY deliveries DESC;

-- Q12. Payment method usage and money collected           [GROUP BY]
SELECT method, COUNT(*) AS payments, SUM(amount) AS total_amount
FROM payments
WHERE payment_status = 'Success'
GROUP BY method;

-- Q13. Restaurants earning more than Rs.500 in total      [HAVING]
SELECT r.name, SUM(oi.quantity * oi.unit_price) AS revenue
FROM restaurants r
JOIN orders      o  ON o.restaurant_id = r.restaurant_id
JOIN order_items oi ON oi.order_id     = o.order_id
WHERE o.status <> 'Cancelled'
GROUP BY r.restaurant_id, r.name
HAVING revenue > 500;

-- Q14. Orders per month                                   [date functions]
SELECT DATE_FORMAT(order_date, '%Y-%m') AS month, COUNT(*) AS orders_placed
FROM orders
GROUP BY DATE_FORMAT(order_date, '%Y-%m')
ORDER BY month;

-- Q15. Rank customers by spending inside each city        [WINDOW FUNCTION, MySQL 8]
SELECT city, name, total_spent,
       RANK() OVER (PARTITION BY city ORDER BY total_spent DESC) AS city_rank
FROM (
    SELECT c.city, c.name, SUM(t.total_amount) AS total_spent
    FROM customers c
    JOIN v_order_totals t ON t.customer_id = c.customer_id
    WHERE t.status <> 'Cancelled'
    GROUP BY c.customer_id, c.city, c.name
) AS spend;

-- Q16. Customers who ordered from EVERY Indore restaurant [relational DIVISION]
SELECT c.name
FROM customers c
JOIN orders o      ON o.customer_id   = c.customer_id
JOIN restaurants r ON r.restaurant_id = o.restaurant_id
WHERE r.city = 'Indore'
GROUP BY c.customer_id, c.name
HAVING COUNT(DISTINCT r.restaurant_id) =
       (SELECT COUNT(*) FROM restaurants WHERE city = 'Indore');

-- Q17. Order whose payment is still pending               [JOIN on view]
SELECT order_id, customer, restaurant, total_amount, method, payment_status
FROM v_order_summary
WHERE payment_status = 'Pending';

-- Q18. Using the stored function
SELECT order_id, fn_order_total(order_id) AS total
FROM orders
WHERE status = 'Delivered';

-- ---------------------------------------------------------------------
-- DML / TRANSACTION DEMOS
-- ---------------------------------------------------------------------

-- D1. Assign agent 1 to order 10 and move it forward       [UPDATE]
UPDATE orders SET agent_id = 1, status = 'Out for Delivery' WHERE order_id = 10;

-- D2. Cancel an order through the stored procedure          [CALL]
--     Order 10 is no longer 'Placed' after D1, so this call fails on purpose:
--     CALL sp_cancel_order(10);   -- ERROR 1644: Only orders in Placed status ...
--     Add a fresh order first to see it succeed:
INSERT INTO orders (customer_id, restaurant_id, status) VALUES (8, 4, 'Placed');
SET @new_order = LAST_INSERT_ID();
INSERT INTO order_items (order_id, item_id, quantity, unit_price) VALUES (@new_order, 10, 1, 90.00);
INSERT INTO payments (order_id, method, amount, payment_status) VALUES (@new_order, 'UPI', 90.00, 'Success');
CALL sp_cancel_order(@new_order);
SELECT order_id, status FROM orders WHERE order_id = @new_order;           -- Cancelled
SELECT order_id, payment_status FROM payments WHERE order_id = @new_order; -- Refunded

-- D3. Trigger test: item 4 (Pizza Planet) into an order from Spice Garden -> error
--     INSERT INTO order_items (order_id, item_id, quantity, unit_price) VALUES (1, 4, 1, 250.00);
--     ERROR 1644: Menu item does not belong to the order's restaurant

-- D4. Transaction with ROLLBACK
START TRANSACTION;
    UPDATE menu_items SET price = price * 1.10 WHERE restaurant_id = 1;
    SELECT name, price FROM menu_items WHERE restaurant_id = 1;   -- see new prices
ROLLBACK;
SELECT name, price FROM menu_items WHERE restaurant_id = 1;       -- original prices back

-- D5. Price change does NOT rewrite history (unit_price snapshot)
UPDATE menu_items SET price = 250.00 WHERE item_id = 1;
SELECT order_id, unit_price FROM order_items WHERE item_id = 1;   -- still 220.00 / 220.00

-- D6. EXPLAIN shows an index being used
EXPLAIN SELECT * FROM orders WHERE order_date >= '2026-09-20';
