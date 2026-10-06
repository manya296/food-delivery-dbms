# Relational Algebra Examples

**Notation**

| Symbol | Operation | SQL equivalent |
|---|---|---|
| σ | Selection (filter rows) | `WHERE` |
| π | Projection (choose columns) | `SELECT` |
| ⨝ | Natural / theta join | `JOIN ... ON` |
| ∪ | Union | `UNION` |
| − | Set difference | `NOT EXISTS` / `LEFT JOIN ... IS NULL` |
| ÷ | Division | `GROUP BY ... HAVING COUNT(...)` |
| ρ | Rename | `AS` |
| γ | Grouping / aggregation | `GROUP BY` + aggregate |

Relation names: `Customers`, `Restaurants`, `MenuItems`, `DeliveryAgents`, `Orders`, `OrderItems`, `Payments`.

---

### RA1 — Selection
*Customers living in Indore.*

```
σ city = 'Indore' (Customers)
```
```sql
SELECT * FROM customers WHERE city = 'Indore';
```

### RA2 — Selection + Projection
*Name and email of customers in Indore.*

```
π name, email ( σ city = 'Indore' (Customers) )
```
```sql
SELECT name, email FROM customers WHERE city = 'Indore';
```

### RA3 — Selection with a compound condition
*Delivered orders placed on or after 15 Sep 2026.*

```
σ status = 'Delivered' ∧ order_date ≥ '2026-09-15' (Orders)
```
```sql
SELECT * FROM orders WHERE status = 'Delivered' AND order_date >= '2026-09-15';
```

### RA4 — Join
*Name of each customer together with the restaurant they ordered from.*

```
π Customers.name, Restaurants.name (
      Customers ⨝ Customers.customer_id = Orders.customer_id Orders
                ⨝ Orders.restaurant_id  = Restaurants.restaurant_id Restaurants )
```
```sql
SELECT c.name, r.name
FROM customers c
JOIN orders o      ON c.customer_id   = o.customer_id
JOIN restaurants r ON o.restaurant_id = r.restaurant_id;
```

### RA5 — Join across the junction table
*Names of menu items ordered in order 1.*

```
π MenuItems.name ( σ order_id = 1 (OrderItems) ⨝ OrderItems.item_id = MenuItems.item_id MenuItems )
```
```sql
SELECT m.name
FROM order_items oi JOIN menu_items m ON oi.item_id = m.item_id
WHERE oi.order_id = 1;
```

### RA6 — Set difference
*IDs of customers who never placed an order.*

```
π customer_id (Customers)  −  π customer_id (Orders)
```
```sql
SELECT customer_id FROM customers
WHERE customer_id NOT IN (SELECT customer_id FROM orders);
```
Result with sample data: customer 8 (Meera Nair).

### RA7 — Union
*All cities where we have either a customer or a restaurant.*

```
π city (Customers)  ∪  π city (Restaurants)
```
```sql
SELECT city FROM customers UNION SELECT city FROM restaurants;
```
Result: Indore, Bhopal, Ujjain.

### RA8 — Rename
*Pairs of different customers living in the same city.*

```
π C1.name, C2.name ( ρ C1 (Customers) ⨝ C1.city = C2.city ∧ C1.customer_id < C2.customer_id  ρ C2 (Customers) )
```
```sql
SELECT c1.name, c2.name
FROM customers c1 JOIN customers c2
  ON c1.city = c2.city AND c1.customer_id < c2.customer_id;
```

### RA9 — Aggregation (γ)
*Number of orders per restaurant.*

```
restaurant_id γ COUNT(order_id) → total_orders (Orders)
```
```sql
SELECT restaurant_id, COUNT(order_id) AS total_orders
FROM orders GROUP BY restaurant_id;
```

### RA10 — Aggregation after a join
*Order total for every order.*

```
order_id γ SUM(quantity × unit_price) → order_total (OrderItems)
```
```sql
SELECT order_id, SUM(quantity * unit_price) AS order_total
FROM order_items GROUP BY order_id;
```

### RA11 — Division
*Customers who have ordered from **every** restaurant located in Indore.*

```
π customer_id, restaurant_id (Orders)  ÷  π restaurant_id ( σ city = 'Indore' (Restaurants) )
```
```sql
SELECT o.customer_id
FROM orders o JOIN restaurants r ON r.restaurant_id = o.restaurant_id
WHERE r.city = 'Indore'
GROUP BY o.customer_id
HAVING COUNT(DISTINCT r.restaurant_id) = (SELECT COUNT(*) FROM restaurants WHERE city = 'Indore');
```
Result with sample data: customers 1 (Aarav) and 3 (Rohan), because Indore has Spice Garden and Pizza Planet.

### RA12 — Intersection (derived from difference)
*Customers who have both a UPI payment and a Card payment.*

```
A = π customer_id ( Orders ⨝ Payments ⨝ σ method='UPI'  ... )
B = π customer_id ( Orders ⨝ Payments ⨝ σ method='Card' ... )
A ∩ B  =  A − (A − B)
```
```sql
SELECT o.customer_id FROM orders o JOIN payments p ON p.order_id = o.order_id WHERE p.method = 'UPI'
INTERSECT   -- MySQL 8.0.31+
SELECT o.customer_id FROM orders o JOIN payments p ON p.order_id = o.order_id WHERE p.method = 'Card';
```
