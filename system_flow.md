# System Flow

This document describes how data moves through the Food Delivery database and how the views, function, stored procedure and trigger support that flow. The table definitions are in [`sql/01_schema.sql`](../sql/01_schema.sql) and the programmable objects are in [`sql/03_views_procedures_triggers.sql`](../sql/03_views_procedures_triggers.sql).

## 1. Overview

The database is organised in three layers.

| Layer | Tables | Role |
|---|---|---|
| Master data | `customers`, `restaurants`, `menu_items`, `delivery_agents` | Entities that exist independently of any order |
| Transactions | `orders`, `order_items` | One row per order, and one row per dish within an order |
| Payments | `payments` | Payment method, amount and status for an order |

Master data is entered once and referenced by ID. Transaction tables hold only foreign keys and the facts that belong to the order itself, which keeps the schema in BCNF (see [`normalization.md`](normalization.md)).

## 2. Order lifecycle

### 2.1 Order is placed

A row is inserted into `orders` with the customer, the restaurant and a status of `Placed`. The `agent_id` is left NULL because no delivery agent has been assigned yet.

```sql
INSERT INTO orders (customer_id, restaurant_id, status)
VALUES (8, 4, 'Placed');
```

### 2.2 Items are added

Each dish is inserted into `order_items` with its quantity. The current menu price is copied into `unit_price`, so later price changes do not alter existing orders.

```sql
INSERT INTO order_items (order_id, item_id, quantity, unit_price)
VALUES (13, 10, 2, 90.00);
```

Before each insert, the trigger `trg_order_items_check_restaurant` verifies that the dish belongs to the restaurant the order was placed with (section 6).

### 2.3 Payment is recorded

A row is inserted into `payments`. UPI and card payments are recorded as `Success`. Cash on delivery starts as `Pending` and is updated when the cash is collected.

```sql
INSERT INTO payments (order_id, method, amount, payment_status, paid_at)
VALUES (13, 'UPI', 180.00, 'Success', NOW());
```

### 2.4 Agent assignment and delivery

An agent is assigned by updating `orders.agent_id`, and the status moves through `Out for Delivery` to `Delivered`.

```sql
UPDATE orders SET agent_id = 2, status = 'Out for Delivery' WHERE order_id = 13;
UPDATE orders SET status = 'Delivered' WHERE order_id = 13;
```

### 2.5 Cancellation

An order that is still `Placed` can be cancelled through the stored procedure `sp_cancel_order` (section 5), which updates the order and its payment together.

### Status transitions

```
Placed ──► Out for Delivery ──► Delivered
  │
  └──► Cancelled
```

## 3. Views

Views store a query, not data. They are used here for information that is derived from several tables.

### 3.1 `v_order_totals`

Returns one row per order with its total amount.

```sql
SELECT o.order_id, o.customer_id, o.restaurant_id, o.order_date, o.status,
       SUM(oi.quantity * oi.unit_price) AS total_amount
FROM orders o
JOIN order_items oi ON oi.order_id = o.order_id
GROUP BY o.order_id, o.customer_id, o.restaurant_id, o.order_date, o.status;
```

The `orders` table has no total column. A stored total would duplicate information already held in `order_items` and could drift out of sync if an item row were edited. The view calculates the total each time it is read, so it is always consistent with the line items.

Orders with no items do not appear in this view because of the inner join.

```sql
SELECT * FROM v_order_totals WHERE order_id = 1;
```

| order_id | customer_id | restaurant_id | order_date | status | total_amount |
|---|---|---|---|---|---|
| 1 | 1 | 1 | 2026-09-01 19:30:00 | Delivered | 600.00 |

### 3.2 `v_order_summary`

A reporting view that joins `v_order_totals` with customers, restaurants, delivery agents and payments, and replaces IDs with names.

Delivery agents and payments are joined with `LEFT JOIN`, so an order still appears before an agent is assigned or a payment is made.

```sql
SELECT * FROM v_order_summary WHERE order_id IN (1, 10);
```

| order_id | customer | restaurant | delivery_agent | status | total_amount | method | payment_status |
|---|---|---|---|---|---|---|---|
| 1 | Aarav Sharma | Spice Garden | Rahul Yadav | Delivered | 600.00 | UPI | Success |
| 10 | Aarav Sharma | Spice Garden | NULL | Placed | 520.00 | COD | Pending |

Because it is built on `v_order_totals`, the summary also reuses the same total calculation.

## 4. Function: `fn_order_total`

```sql
fn_order_total(p_order_id INT) RETURNS DECIMAL(10,2)
```

Returns the total of a single order by summing `quantity * unit_price` over its rows in `order_items`. `COALESCE` makes it return 0 for an order with no items instead of NULL.

A function returns one value and can be used inside a query, which is what separates it from a view (a set of rows) and a procedure (called on its own).

```sql
SELECT fn_order_total(1);        -- 600.00
SELECT fn_order_total(10);       -- 520.00

SELECT order_id, fn_order_total(order_id) AS total
FROM orders
WHERE status = 'Delivered';
```

## 5. Stored procedure: `sp_cancel_order`

```sql
CALL sp_cancel_order(p_order_id);
```

Cancelling an order touches two tables, `orders` and `payments`. The procedure performs both updates inside a single transaction so the database never ends up with a cancelled order and an untouched payment.

Steps performed by the procedure:

1. `START TRANSACTION`.
2. Read the order's status with `SELECT ... FOR UPDATE`, which locks the row so another session cannot change it between the check and the update.
3. If the status is `Placed`:
   - set `orders.status` to `Cancelled`;
   - set `payments.payment_status` to `Refunded` if it was `Success`, otherwise `Failed`;
   - `COMMIT`.
4. Otherwise, `ROLLBACK` and raise an error with `SIGNAL`.

An order that has already left the restaurant, been delivered or been cancelled cannot be cancelled again. A non-existent order ID is rejected the same way.

Example with order 10, which is `Placed` with a `Pending` payment:

```sql
CALL sp_cancel_order(10);

SELECT o.order_id, o.status, p.payment_status
FROM orders o
JOIN payments p ON p.order_id = o.order_id
WHERE o.order_id = 10;
```

| order_id | status | payment_status |
|---|---|---|
| 10 | Cancelled | Failed |

Example with order 9, which is already `Out for Delivery`:

```sql
CALL sp_cancel_order(9);
-- ERROR 1644 (45000): Only orders in Placed status can be cancelled
```

## 6. Trigger: `trg_order_items_check_restaurant`

A foreign key on `order_items.item_id` guarantees that the dish exists, but not that it belongs to the restaurant the order was placed with. The trigger fires `BEFORE INSERT` on `order_items` and compares the restaurant of the order with the restaurant of the dish. If they differ, the insert is rejected.

```sql
-- Order 1 is from Spice Garden; item 4 is a Pizza Planet dish
INSERT INTO order_items (order_id, item_id, quantity, unit_price)
VALUES (1, 4, 1, 250.00);
-- ERROR 1644 (45000): Menu item does not belong to the order's restaurant
```

## 7. Integrity rules at a glance

| Rule | Mechanism |
|---|---|
| Phone number must be 10 digits | `CHECK` on `customers.phone` |
| Email and phone are unique per customer | `UNIQUE` |
| A customer or restaurant with orders cannot be deleted | `ON DELETE RESTRICT` on `orders` |
| Deleting an order removes its items and payment | `ON DELETE CASCADE` on `order_items` and `payments` |
| Deleting an agent keeps the order | `ON DELETE SET NULL` on `orders.agent_id` |
| One payment per order | `UNIQUE` on `payments.order_id` |
| Items must belong to the order's restaurant | Trigger (section 6) |
| Order cancellation is atomic and only allowed from `Placed` | Stored procedure with a transaction (section 5) |
| Order total is never stored | View and function (sections 3 and 4) |

## 8. Where each object is used

| Object | Type | Used in |
|---|---|---|
| `v_order_totals` | View | Queries Q10 and Q15, and as the base of `v_order_summary` |
| `v_order_summary` | View | Query Q17 |
| `fn_order_total` | Function | Query Q18 |
| `sp_cancel_order` | Procedure | Demo D2 in `04_queries.sql` |
| `trg_order_items_check_restaurant` | Trigger | Runs on every insert into `order_items` |
