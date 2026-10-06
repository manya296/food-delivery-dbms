# Normalization: UNF → 1NF → 2NF → 3NF → BCNF

We start from what a restaurant owner might keep in a single spreadsheet, then remove
redundancy step by step until we reach the 7 tables in `sql/01_schema.sql`.

## 0. Un-normalized table (UNF)

`FOOD_ORDER_SHEET`

| order_id | order_date | cust_name | cust_email | cust_phone | cust_city | rest_name | rest_city | cuisine | agent_name | agent_phone | items | pay_method | pay_status |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 1 | 2026-09-01 | Aarav Sharma | aarav.sharma@example.com | 9876500001 | Indore | Spice Garden | Indore | North Indian | Rahul Yadav | 9811100001 | Paneer Butter Masala ×2 @220, Butter Naan ×4 @40 | UPI | Success |
| 4 | 2026-09-08 | Rohan Mehta | rohan.mehta@example.com | 9876500003 | Indore | Spice Garden | Indore | North Indian | Rahul Yadav | 9811100001 | Dal Makhani ×1 @180, Butter Naan ×2 @40 | UPI | Success |

### Problems (anomalies)

| Anomaly | Example |
|---|---|
| **Multi-valued column** | `items` holds several items in one cell, so we cannot search or total them with SQL |
| **Insert anomaly** | A new customer cannot be stored until they place an order |
| **Update anomaly** | If Rahul changes phone number, every row with Rahul must be edited |
| **Delete anomaly** | Deleting the only order of a customer also deletes the customer's details |
| **Redundancy** | "Spice Garden / Indore / North Indian" is repeated on every Spice Garden order |

---

## 1. First Normal Form (1NF)

**Rule:** every column holds a single atomic value, no repeating groups, and there is a primary key.

Fix: split `items` so there is **one row per (order, item)**.

`FOOD_ORDER_1NF` — primary key **(order_id, item_name)**

| order_id | item_name | quantity | unit_price | order_date | cust_name | cust_email | … other order columns … |
|---|---|---|---|---|---|---|---|
| 1 | Paneer Butter Masala | 2 | 220 | 2026-09-01 | Aarav Sharma | aarav…@example.com | … |
| 1 | Butter Naan | 4 | 40 | 2026-09-01 | Aarav Sharma | aarav…@example.com | … |

Customer, restaurant and agent data is still repeated, so we move on.

---

## 2. Second Normal Form (2NF)

**Rule:** in 1NF **and** no *partial dependency*, meaning no non-key column may depend on only
a **part** of a composite key.

Composite key: `(order_id, item_name)`

| Dependency | Type |
|---|---|
| (order_id, item_name) → quantity | full ✅ |
| order_id → order_date, customer details, restaurant details, agent details, payment details | **partial ❌** |
| item_name → category, current price | **partial ❌** |

Fix: split into three relations.

* `ORDER_HEADER(order_id, order_date, cust_*, rest_*, agent_*, pay_*)`  — depends on `order_id`
* `ITEM(item_name, category, price)`  — depends on the item
* `ORDER_ITEM(order_id, item_name, quantity, unit_price)`  — depends on the whole key

---

## 3. Third Normal Form (3NF)

**Rule:** in 2NF **and** no *transitive dependency* (non-key → non-key).

In `ORDER_HEADER`:

```
order_id → customer_email → cust_name, cust_phone, cust_city      (transitive ❌)
order_id → restaurant      → rest_city, cuisine, rating            (transitive ❌)
order_id → agent           → agent_phone, vehicle_type             (transitive ❌)
```

Fix: give each real-world entity its own table and keep only a **foreign key** in `orders`.

| New table | Key | Non-key attributes |
|---|---|---|
| `customers` | customer_id | name, email, phone, city, created_at |
| `restaurants` | restaurant_id | name, city, cuisine, rating |
| `delivery_agents` | agent_id | name, phone, vehicle_type, city |
| `menu_items` | item_id | restaurant_id (FK), name, category, price, is_available |
| `orders` | order_id | customer_id (FK), restaurant_id (FK), agent_id (FK), order_date, status |
| `order_items` | (order_id, item_id) | quantity, unit_price |
| `payments` | payment_id (order_id is UNIQUE) | method, amount, payment_status, paid_at |

---

## 4. Boyce–Codd Normal Form (BCNF)

**Rule:** for every non-trivial functional dependency X → Y, **X must be a superkey**.

| Table | Functional dependencies | Determinants are superkeys? |
|---|---|---|
| customers | customer_id → all; email → all; phone → all | ✅ (all are candidate keys) |
| restaurants | restaurant_id → name, city, cuisine, rating | ✅ |
| menu_items | item_id → all; (restaurant_id, name) → all | ✅ (both candidate keys) |
| delivery_agents | agent_id → all; phone → all | ✅ |
| orders | order_id → customer_id, restaurant_id, agent_id, order_date, status | ✅ |
| order_items | (order_id, item_id) → quantity, unit_price | ✅ |
| payments | payment_id → all; order_id → all | ✅ |

All determinants are superkeys, so the schema is in **BCNF** (and therefore 3NF).

---

## Design decisions worth explaining to faculty

1. **No `total_amount` column in `orders`.** It can be computed from `order_items`, so storing it
   would create a derived-data redundancy and risk inconsistency. We expose it through the view
   `v_order_totals` instead.

2. **`order_items.unit_price` looks redundant with `menu_items.price`, but it is not.**
   `menu_items.price` is the *current* price; `unit_price` records the price *at the time of the order*.
   They are different facts that can diverge (see demo D5 in `04_queries.sql`).

3. **`order_items` resolves a many-to-many relationship.** One order has many items and one item appears in
   many orders, so a junction table with a composite primary key is required.

4. **`payments.order_id` is UNIQUE** to model a one-to-one relationship (one payment per order).

5. **A rule that foreign keys cannot express:** an order may only contain items from *its* restaurant.
   This is enforced by the trigger `trg_order_items_check_restaurant`.

6. **Nullable `orders.agent_id`.** An order exists before an agent is assigned, so the relationship is optional on
   the agent side (`ON DELETE SET NULL` keeps order history if an agent leaves).

7. **Ways to go further (not needed for BCNF):** a separate `cities` table would remove repeated city strings;
   a `categories` table would do the same for `menu_items.category`. We kept them as plain columns to keep the
   project readable.
