-- =====================================================================
-- 03_views_procedures_triggers.sql  |  Run AFTER 02_sample_data.sql
-- =====================================================================
USE food_delivery;

-- ---------------------------------------------------------------------
-- VIEWS
-- ---------------------------------------------------------------------

-- Order total is derived from order_items, so it is never stored twice.
CREATE OR REPLACE VIEW v_order_totals AS
SELECT o.order_id,
       o.customer_id,
       o.restaurant_id,
       o.order_date,
       o.status,
       SUM(oi.quantity * oi.unit_price) AS total_amount
FROM orders o
JOIN order_items oi ON oi.order_id = o.order_id
GROUP BY o.order_id, o.customer_id, o.restaurant_id, o.order_date, o.status;

-- Human-readable order summary (joins 4 tables).
CREATE OR REPLACE VIEW v_order_summary AS
SELECT t.order_id,
       c.name  AS customer,
       r.name  AS restaurant,
       a.name  AS delivery_agent,
       t.order_date,
       t.status,
       t.total_amount,
       p.method,
       p.payment_status
FROM v_order_totals t
JOIN customers   c ON c.customer_id   = t.customer_id
JOIN restaurants r ON r.restaurant_id = t.restaurant_id
JOIN orders      o ON o.order_id      = t.order_id
LEFT JOIN delivery_agents a ON a.agent_id = o.agent_id
LEFT JOIN payments        p ON p.order_id = t.order_id;

DELIMITER $$

-- ---------------------------------------------------------------------
-- STORED FUNCTION: total of one order
-- ---------------------------------------------------------------------
CREATE FUNCTION fn_order_total(p_order_id INT)
RETURNS DECIMAL(10,2)
READS SQL DATA
BEGIN
    DECLARE v_total DECIMAL(10,2);
    SELECT COALESCE(SUM(quantity * unit_price), 0)
      INTO v_total
      FROM order_items
     WHERE order_id = p_order_id;
    RETURN v_total;
END$$

-- ---------------------------------------------------------------------
-- STORED PROCEDURE: cancel an order inside a transaction
-- Only orders still in 'Placed' status can be cancelled.
-- ---------------------------------------------------------------------
CREATE PROCEDURE sp_cancel_order(IN p_order_id INT)
BEGIN
    DECLARE v_status VARCHAR(20);

    START TRANSACTION;

    SELECT status INTO v_status
      FROM orders
     WHERE order_id = p_order_id
       FOR UPDATE;

    IF v_status = 'Placed' THEN
        UPDATE orders SET status = 'Cancelled' WHERE order_id = p_order_id;

        UPDATE payments
           SET payment_status = CASE WHEN payment_status = 'Success'
                                     THEN 'Refunded' ELSE 'Failed' END
         WHERE order_id = p_order_id;

        COMMIT;
    ELSE
        ROLLBACK;
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Only orders in Placed status can be cancelled';
    END IF;
END$$

-- ---------------------------------------------------------------------
-- TRIGGER: an order may only contain items from its own restaurant
-- (a plain foreign key cannot enforce this rule)
-- ---------------------------------------------------------------------
CREATE TRIGGER trg_order_items_check_restaurant
BEFORE INSERT ON order_items
FOR EACH ROW
BEGIN
    DECLARE v_order_rest INT;
    DECLARE v_item_rest  INT;

    SELECT restaurant_id INTO v_order_rest FROM orders     WHERE order_id = NEW.order_id;
    SELECT restaurant_id INTO v_item_rest  FROM menu_items WHERE item_id  = NEW.item_id;

    IF v_order_rest <> v_item_rest THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Menu item does not belong to the order''s restaurant';
    END IF;
END$$

DELIMITER ;
