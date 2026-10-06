-- =====================================================================
-- 02_sample_data.sql  |  Run AFTER 01_schema.sql
-- =====================================================================
USE food_delivery;

INSERT INTO customers (customer_id, name, email, phone, city, created_at) VALUES
(1, 'Aarav Sharma', 'aarav.sharma@example.com', '9876500001', 'Indore', '2026-08-01 10:00:00'),
(2, 'Priya Verma',  'priya.verma@example.com',  '9876500002', 'Bhopal', '2026-08-03 11:30:00'),
(3, 'Rohan Mehta',  'rohan.mehta@example.com',  '9876500003', 'Indore', '2026-08-05 09:15:00'),
(4, 'Sneha Patel',  'sneha.patel@example.com',  '9876500004', 'Ujjain', '2026-08-10 14:00:00'),
(5, 'Kabir Singh',  'kabir.singh@example.com',  '9876500005', 'Bhopal', '2026-08-12 16:45:00'),
(6, 'Ananya Joshi', 'ananya.joshi@example.com', '9876500006', 'Indore', '2026-08-15 12:20:00'),
(7, 'Vikram Rao',   'vikram.rao@example.com',   '9876500007', 'Ujjain', '2026-08-20 18:10:00'),
(8, 'Meera Nair',   'meera.nair@example.com',   '9876500008', 'Bhopal', '2026-09-02 08:05:00');

INSERT INTO restaurants (restaurant_id, name, city, cuisine, rating) VALUES
(1, 'Spice Garden', 'Indore', 'North Indian', 4.3),
(2, 'Pizza Planet', 'Indore', 'Italian',      4.0),
(3, 'Dragon Wok',   'Bhopal', 'Chinese',      4.1),
(4, 'South Spoon',  'Bhopal', 'South Indian', 4.5),
(5, 'Burger Barn',  'Ujjain', 'Fast Food',    3.8);

INSERT INTO menu_items (item_id, restaurant_id, name, category, price, is_available) VALUES
( 1, 1, 'Paneer Butter Masala', 'Main Course', 220.00, TRUE),
( 2, 1, 'Butter Naan',          'Bread',        40.00, TRUE),
( 3, 1, 'Dal Makhani',          'Main Course', 180.00, TRUE),
( 4, 2, 'Margherita Pizza',     'Pizza',       250.00, TRUE),
( 5, 2, 'Garlic Bread',         'Starter',     120.00, TRUE),
( 6, 2, 'Pasta Alfredo',        'Pasta',       210.00, TRUE),
( 7, 3, 'Veg Hakka Noodles',    'Noodles',     160.00, TRUE),
( 8, 3, 'Veg Manchurian',       'Starter',     150.00, TRUE),
( 9, 3, 'Fried Rice',           'Rice',        170.00, TRUE),
(10, 4, 'Masala Dosa',          'Breakfast',    90.00, TRUE),
(11, 4, 'Idli Sambar',          'Breakfast',    70.00, TRUE),
(12, 4, 'Filter Coffee',        'Beverage',     40.00, TRUE),
(13, 5, 'Aloo Tikki Burger',    'Burger',       80.00, TRUE),
(14, 5, 'French Fries',         'Sides',        70.00, TRUE),
(15, 5, 'Cold Coffee',          'Beverage',     90.00, FALSE);

INSERT INTO delivery_agents (agent_id, name, phone, vehicle_type, city) VALUES
(1, 'Rahul Yadav', '9811100001', 'Bike',    'Indore'),
(2, 'Imran Khan',  '9811100002', 'Scooter', 'Bhopal'),
(3, 'Deepak Jain', '9811100003', 'Bike',    'Ujjain'),
(4, 'Sunita Devi', '9811100004', 'Scooter', 'Indore');

INSERT INTO orders (order_id, customer_id, restaurant_id, agent_id, order_date, status) VALUES
( 1, 1, 1, 1,    '2026-09-01 19:30:00', 'Delivered'),
( 2, 1, 2, 4,    '2026-09-05 20:15:00', 'Delivered'),
( 3, 2, 3, 2,    '2026-09-06 13:00:00', 'Delivered'),
( 4, 3, 1, 1,    '2026-09-08 21:00:00', 'Delivered'),
( 5, 4, 5, 3,    '2026-09-10 18:45:00', 'Delivered'),
( 6, 5, 4, 2,    '2026-09-12 08:30:00', 'Delivered'),
( 7, 6, 2, NULL, '2026-09-15 19:00:00', 'Cancelled'),
( 8, 2, 4, 2,    '2026-09-18 09:15:00', 'Delivered'),
( 9, 3, 2, 4,    '2026-09-20 20:30:00', 'Out for Delivery'),
(10, 1, 1, NULL, '2026-09-25 19:50:00', 'Placed'),
(11, 7, 5, 3,    '2026-09-27 17:30:00', 'Delivered'),
(12, 5, 3, 2,    '2026-10-01 12:45:00', 'Delivered');

INSERT INTO order_items (order_id, item_id, quantity, unit_price) VALUES
( 1,  1, 2, 220.00), ( 1,  2, 4,  40.00),
( 2,  4, 1, 250.00), ( 2,  5, 1, 120.00),
( 3,  7, 2, 160.00), ( 3,  8, 1, 150.00),
( 4,  3, 1, 180.00), ( 4,  2, 2,  40.00),
( 5, 13, 3,  80.00), ( 5, 14, 2,  70.00),
( 6, 10, 2,  90.00), ( 6, 12, 2,  40.00),
( 7,  6, 1, 210.00),
( 8, 11, 3,  70.00), ( 8, 10, 1,  90.00),
( 9,  4, 2, 250.00), ( 9,  6, 1, 210.00),
(10,  1, 1, 220.00), (10,  3, 1, 180.00), (10, 2, 3, 40.00),
(11, 13, 2,  80.00), (11, 14, 1,  70.00),
(12,  9, 1, 170.00), (12,  8, 2, 150.00);

-- Payment amounts equal the order totals computed from order_items.
INSERT INTO payments (payment_id, order_id, method, amount, payment_status, paid_at) VALUES
( 1,  1, 'UPI',  600.00, 'Success',  '2026-09-01 19:31:00'),
( 2,  2, 'Card', 370.00, 'Success',  '2026-09-05 20:16:00'),
( 3,  3, 'COD',  470.00, 'Success',  '2026-09-06 13:40:00'),
( 4,  4, 'UPI',  260.00, 'Success',  '2026-09-08 21:01:00'),
( 5,  5, 'COD',  380.00, 'Success',  '2026-09-10 19:20:00'),
( 6,  6, 'Card', 260.00, 'Success',  '2026-09-12 08:31:00'),
( 7,  7, 'UPI',  210.00, 'Refunded', '2026-09-15 19:01:00'),
( 8,  8, 'UPI',  300.00, 'Success',  '2026-09-18 09:16:00'),
( 9,  9, 'Card', 710.00, 'Success',  '2026-09-20 20:31:00'),
(10, 10, 'COD',  520.00, 'Pending',  NULL),
(11, 11, 'UPI',  230.00, 'Success',  '2026-09-27 17:31:00'),
(12, 12, 'Card', 470.00, 'Success',  '2026-10-01 12:46:00');
