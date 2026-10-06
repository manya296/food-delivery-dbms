# Viva / Presentation Prep

## 2-minute explanation script

> "My project is a database for an online food delivery platform, built in MySQL. It has 7 tables:
> customers, restaurants, menu_items, delivery_agents, orders, order_items and payments.
> I started from a single un-normalized spreadsheet and normalized it up to BCNF.
> The ER diagram shows one-to-many relationships such as customer → orders and restaurant → menu items,
> a many-to-many relationship between orders and menu items resolved by the order_items table, and a
> one-to-one relationship between an order and its payment.
> I wrote DDL with constraints, loaded sample data, and wrote 18 queries covering joins, grouping, subqueries,
> window functions and relational division, plus views, a stored function, a stored procedure with a
> transaction, and a trigger. I also mapped several queries to relational algebra."

## Likely questions and short answers

| Question | Answer |
|---|---|
| Why is `order_items` needed? | Orders and menu items are many-to-many. A junction table with composite PK (order_id, item_id) resolves it. |
| Why no `total_amount` in `orders`? | It is derived from `order_items`; storing it risks inconsistency. It is exposed through the view `v_order_totals`. |
| Why store `unit_price` if `menu_items` has `price`? | `price` is current; `unit_price` is the price at purchase time. Historical orders must not change when the menu changes. |
| Which normal form is the schema in? | BCNF: every determinant in every table is a superkey. See `docs/normalization.md`. |
| Difference between 3NF and BCNF? | 3NF allows a dependency X → Y if Y is a prime attribute; BCNF requires X to always be a superkey. |
| What is a partial dependency? | A non-key attribute depending on part of a composite key (2NF violation). |
| What is a transitive dependency? | A → B and B → C where B is not a key, so A → C indirectly (3NF violation). |
| What do the foreign key actions do? | `CASCADE` deletes children with the parent (menu items, order items, payments); `RESTRICT` blocks deleting a customer or restaurant that has orders; `SET NULL` keeps an order if its agent is deleted. |
| What does the trigger do? | Rejects an order item whose menu item belongs to a different restaurant than the order. |
| Why a transaction in `sp_cancel_order`? | Order status and payment status must change together or not at all (atomicity). `FOR UPDATE` locks the row to avoid a race. |
| Why index `order_date`, `status`, `city`? | They are common filter columns; run `EXPLAIN` (demo D6) to show the index being used. |
| INNER JOIN vs LEFT JOIN? | INNER returns only matching rows; LEFT keeps all left rows, with NULLs when there is no match (Q3, Q7, Q11). |
| WHERE vs HAVING? | WHERE filters rows before grouping; HAVING filters groups after aggregation (Q13). |
| What is a view? | A saved query that behaves like a virtual table. It stores no data. |
| What are ACID properties? | Atomicity, Consistency, Isolation, Durability. InnoDB supports them. |

## Demo flow (5 minutes)

1. Open `README.md` on GitHub and show the ER diagram.
2. In MySQL Workbench run the four SQL files in order.
3. Show `SHOW TABLES;` and `SELECT * FROM orders;`.
4. Run Q3 (joins), Q5 (revenue), Q7 (LEFT JOIN … IS NULL), Q15 (window function).
5. Show the trigger rejecting a bad insert (D3) and the cancel procedure (D2).
6. Open `docs/normalization.md` and walk through UNF → BCNF.
7. Open `docs/relational_algebra.md` and show RA4 and RA11 next to their SQL.
