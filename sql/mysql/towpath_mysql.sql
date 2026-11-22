-- =====================================================================
--  THE TOWPATH – SQL PROJECT (MySQL 8)
--  Canalside café + convenience store, Jan 2024 – Dec 2025
--  Author: Bhavan Chandupatla
--
--  HOW TO RUN (MySQL Workbench)
--  1. Copy the repo folder data/clean/csv/ to C:/Towpath/csv/
--     (or change the file paths in PART 2 to where the CSVs are)
--  2. Allow file loading (once):
--       a) Run:  SET GLOBAL local_infile = 1;
--       b) Workbench > Database > Manage Connections > your connection >
--          Advanced > Others box, add the line:  OPT_LOCAL_INFILE=1
--          Then close and reopen the connection.
--  3. Run PART 1 and PART 2 (Ctrl+Shift+Enter runs the whole script).
--  4. Run the PART 3 queries one at a time (put the cursor in a query
--     and press Ctrl+Enter).
--  If your CSV folder is elsewhere, change the paths in PART 2.
-- =====================================================================


-- =====================================================================
--  PART 1 – CREATE THE DATABASE AND TABLES (star schema)
--  Fact tables: sales, wastage, shifts, purchases
--  Dimension tables: products, suppliers, staff, weather
-- =====================================================================
DROP DATABASE IF EXISTS towpath;
CREATE DATABASE towpath CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci;
USE towpath;

CREATE TABLE suppliers (
    supplier_id    VARCHAR(10)  PRIMARY KEY,
    supplier_name  VARCHAR(60)  NOT NULL,
    delivery_cost  DECIMAL(8,2) NOT NULL,
    delivery_days  VARCHAR(30)
);

CREATE TABLE products (
    product_id     VARCHAR(10)  PRIMARY KEY,
    product_name   VARCHAR(60)  NOT NULL,
    category       VARCHAR(30)  NOT NULL,
    business_area  VARCHAR(10)  NOT NULL,          -- 'Café' or 'Store'
    cost_price     DECIMAL(8,2) NOT NULL,          -- current (Dec 2025) cost
    selling_price  DECIMAL(8,2) NOT NULL,          -- current (Dec 2025) price
    supplier_id    VARCHAR(10)  NOT NULL,
    FOREIGN KEY (supplier_id) REFERENCES suppliers (supplier_id)
);

CREATE TABLE staff (
    staff_id       VARCHAR(10)  PRIMARY KEY,
    name           VARCHAR(60)  NOT NULL,
    role           VARCHAR(30),
    hourly_rate    DECIMAL(6,2),
    business_area  VARCHAR(10)                     -- 'Café', 'Store', 'Both', 'Unknown'
);

CREATE TABLE weather (
    date           DATE         PRIMARY KEY,
    avg_temp_c     DECIMAL(4,1),
    rainfall_mm    DECIMAL(5,1),
    `condition`    VARCHAR(15)  NOT NULL           -- Sunny, Cloudy, Rain, Heavy Rain, Not recorded
);

-- Grain: one row = one product line on a till receipt
CREATE TABLE sales (
    sales_line_id  INT          PRIMARY KEY,
    transaction_id VARCHAR(10)  NOT NULL,          -- receipt (one customer)
    date           DATE         NOT NULL,
    time           TIME         NOT NULL,
    product_id     VARCHAR(10)  NOT NULL,
    quantity       INT          NOT NULL,
    unit_price     DECIMAL(8,2) NOT NULL,          -- price the customer paid
    unit_cost      DECIMAL(8,2) NOT NULL,          -- cost at that week's delivery
    payment_method VARCHAR(15)  NOT NULL,
    staff_id       VARCHAR(10)  NOT NULL,
    line_type      VARCHAR(12)  NOT NULL,          -- Sale, Refund, Zero, Suspicious (qty > 10)
    FOREIGN KEY (product_id) REFERENCES products (product_id),
    FOREIGN KEY (staff_id)   REFERENCES staff (staff_id),
    INDEX ix_sales_date (date),
    INDEX ix_sales_txn  (transaction_id)
);

CREATE TABLE wastage (
    waste_id        VARCHAR(10) PRIMARY KEY,
    date            DATE        NOT NULL,
    product_id      VARCHAR(10) NOT NULL,
    quantity_wasted INT         NOT NULL,
    reason          VARCHAR(30) NOT NULL,
    FOREIGN KEY (product_id) REFERENCES products (product_id)
);

CREATE TABLE shifts (
    shift_id    VARCHAR(10)  PRIMARY KEY,
    staff_id    VARCHAR(10)  NOT NULL,
    date        DATE         NOT NULL,
    start_time  TIME         NOT NULL,
    end_time    TIME         NOT NULL,
    hours       DECIMAL(4,2) NOT NULL,
    FOREIGN KEY (staff_id) REFERENCES staff (staff_id)
);

CREATE TABLE purchases (
    purchase_id    VARCHAR(10)  PRIMARY KEY,
    delivery_week  DATE         NOT NULL,          -- Monday of delivery week
    supplier_id    VARCHAR(10)  NOT NULL,
    product_id     VARCHAR(10)  NOT NULL,
    quantity       INT          NOT NULL,
    unit_cost      DECIMAL(8,2) NOT NULL,
    FOREIGN KEY (supplier_id) REFERENCES suppliers (supplier_id),
    FOREIGN KEY (product_id)  REFERENCES products (product_id)
);


-- =====================================================================
--  PART 2 – LOAD THE CLEAN CSV FILES
--  Load dimension tables first, so the foreign keys are satisfied.
-- =====================================================================
LOAD DATA LOCAL INFILE 'C:/Towpath/csv/suppliers.csv' INTO TABLE suppliers
  CHARACTER SET utf8mb4 FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
  LINES TERMINATED BY '\n' IGNORE 1 LINES;

LOAD DATA LOCAL INFILE 'C:/Towpath/csv/products.csv' INTO TABLE products
  CHARACTER SET utf8mb4 FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
  LINES TERMINATED BY '\n' IGNORE 1 LINES;

LOAD DATA LOCAL INFILE 'C:/Towpath/csv/staff.csv' INTO TABLE staff
  CHARACTER SET utf8mb4 FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
  LINES TERMINATED BY '\n' IGNORE 1 LINES;

LOAD DATA LOCAL INFILE 'C:/Towpath/csv/weather.csv' INTO TABLE weather
  CHARACTER SET utf8mb4 FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
  LINES TERMINATED BY '\n' IGNORE 1 LINES;

LOAD DATA LOCAL INFILE 'C:/Towpath/csv/sales.csv' INTO TABLE sales
  CHARACTER SET utf8mb4 FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
  LINES TERMINATED BY '\n' IGNORE 1 LINES;

LOAD DATA LOCAL INFILE 'C:/Towpath/csv/wastage.csv' INTO TABLE wastage
  CHARACTER SET utf8mb4 FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
  LINES TERMINATED BY '\n' IGNORE 1 LINES;

LOAD DATA LOCAL INFILE 'C:/Towpath/csv/shifts.csv' INTO TABLE shifts
  CHARACTER SET utf8mb4 FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
  LINES TERMINATED BY '\n' IGNORE 1 LINES;

LOAD DATA LOCAL INFILE 'C:/Towpath/csv/purchases.csv' INTO TABLE purchases
  CHARACTER SET utf8mb4 FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
  LINES TERMINATED BY '\n' IGNORE 1 LINES;


-- =====================================================================
--  PART 3 – ANALYSIS
--  Rules used throughout:
--   * Revenue = quantity * unit_price, excluding 'Suspicious' lines
--     (refunds are kept, so they reduce revenue)
--   * Customers = COUNT(DISTINCT transaction_id) on 'Sale' lines
--     (one row = one receipt line, not one customer)
-- =====================================================================

-- ---------------------------------------------------------------------
-- 3.0  Load checks – compare with the expected counts
--      sales 76,856 | products 40 | staff 10 | shifts 3,342
--      wastage 5,003 | suppliers 6 | purchases 4,183 | weather 731
-- ---------------------------------------------------------------------
SELECT 'sales' AS table_name, COUNT(*) AS row_count FROM sales
UNION ALL SELECT 'products',  COUNT(*) FROM products
UNION ALL SELECT 'staff',     COUNT(*) FROM staff
UNION ALL SELECT 'shifts',    COUNT(*) FROM shifts
UNION ALL SELECT 'wastage',   COUNT(*) FROM wastage
UNION ALL SELECT 'suppliers', COUNT(*) FROM suppliers
UNION ALL SELECT 'purchases', COUNT(*) FROM purchases
UNION ALL SELECT 'weather',   COUNT(*) FROM weather;

-- Data-quality flags kept in the data (not deleted)
SELECT line_type, COUNT(*) AS lines
FROM   sales
GROUP BY line_type;


-- ---------------------------------------------------------------------
-- 3.1  Total revenue (expected: £274,997.44)
-- ---------------------------------------------------------------------
SELECT ROUND(SUM(quantity * unit_price), 2) AS total_revenue
FROM   sales
WHERE  line_type <> 'Suspicious';


-- ---------------------------------------------------------------------
-- 3.2  Revenue by year and business area (year-on-year)
--      Finding: Café +12.4%, Store −8.3%
-- ---------------------------------------------------------------------
SELECT   YEAR(s.date) AS year,
         p.business_area,
         ROUND(SUM(s.quantity * s.unit_price), 2) AS total_revenue
FROM     sales AS s
JOIN     products AS p ON s.product_id = p.product_id
WHERE    s.line_type <> 'Suspicious'
GROUP BY YEAR(s.date), p.business_area
ORDER BY year, p.business_area;

-- Same result side by side, with % change (conditional aggregation + CTE)
WITH area_year AS (
    SELECT   p.business_area,
             SUM(CASE WHEN YEAR(s.date) = 2024 THEN s.quantity * s.unit_price END) AS revenue_2024,
             SUM(CASE WHEN YEAR(s.date) = 2025 THEN s.quantity * s.unit_price END) AS revenue_2025
    FROM     sales AS s
    JOIN     products AS p ON s.product_id = p.product_id
    WHERE    s.line_type <> 'Suspicious'
    GROUP BY p.business_area
)
SELECT business_area,
       ROUND(revenue_2024, 2) AS revenue_2024,
       ROUND(revenue_2025, 2) AS revenue_2025,
       ROUND((revenue_2025 - revenue_2024) * 100.0 / revenue_2024, 1) AS change_pct
FROM   area_year;


-- ---------------------------------------------------------------------
-- 3.3  Store customers per year – fewer customers or smaller spend?
--      Finding: customers −11.0%, average spend slightly up
-- ---------------------------------------------------------------------
SELECT   YEAR(s.date) AS year,
         COUNT(DISTINCT s.transaction_id) AS customers,
         ROUND(SUM(s.quantity * s.unit_price)
               / COUNT(DISTINCT s.transaction_id), 2) AS avg_spend
FROM     sales AS s
JOIN     products AS p ON s.product_id = p.product_id
WHERE    p.business_area = 'Store'
  AND    s.line_type = 'Sale'
GROUP BY YEAR(s.date)
ORDER BY year;


-- ---------------------------------------------------------------------
-- 3.4  Store customers by month, 2024 vs 2025, normalised per day
--      (Feb 2024 had 29 days, so compare customers PER DAY)
-- ---------------------------------------------------------------------
WITH monthly AS (
    SELECT   MONTH(s.date) AS month,
             COUNT(DISTINCT CASE WHEN YEAR(s.date) = 2024 THEN s.transaction_id END) AS customers_2024,
             COUNT(DISTINCT CASE WHEN YEAR(s.date) = 2025 THEN s.transaction_id END) AS customers_2025,
             COUNT(DISTINCT CASE WHEN YEAR(s.date) = 2024 THEN s.date END)           AS days_2024,
             COUNT(DISTINCT CASE WHEN YEAR(s.date) = 2025 THEN s.date END)           AS days_2025
    FROM     sales AS s
    JOIN     products AS p ON s.product_id = p.product_id
    WHERE    p.business_area = 'Store'
      AND    s.line_type = 'Sale'
    GROUP BY MONTH(s.date)
)
SELECT   month,
         customers_2024,
         customers_2025,
         ROUND(customers_2024 * 1.0 / days_2024, 1) AS per_day_2024,
         ROUND(customers_2025 * 1.0 / days_2025, 1) AS per_day_2025,
         ROUND((customers_2025 * 1.0 / days_2025 - customers_2024 * 1.0 / days_2024) * 100.0
               / (customers_2024 * 1.0 / days_2024), 1) AS change_pct
FROM     monthly
ORDER BY month;

-- Before vs after April 2025 (Jan–Mar about −3%, Apr–Dec about −13%)
SELECT   CASE WHEN MONTH(s.date) <= 3 THEN 'Jan-Mar' ELSE 'Apr-Dec' END AS period,
         COUNT(DISTINCT CASE WHEN YEAR(s.date) = 2024 THEN s.transaction_id END) AS customers_2024,
         COUNT(DISTINCT CASE WHEN YEAR(s.date) = 2025 THEN s.transaction_id END) AS customers_2025
FROM     sales AS s
JOIN     products AS p ON s.product_id = p.product_id
WHERE    p.business_area = 'Store'
  AND    s.line_type = 'Sale'
GROUP BY CASE WHEN MONTH(s.date) <= 3 THEN 'Jan-Mar' ELSE 'Apr-Dec' END;


-- ---------------------------------------------------------------------
-- 3.5  Gross margin by category
--      a) Price list margin (current prices, from products)
--      b) Actual margin on sales (cost paid at the time)
--      Finding: café categories ~75–85%, store ~25–60%, Dairy lowest
-- ---------------------------------------------------------------------
SELECT   category,
         business_area,
         ROUND(AVG((selling_price - cost_price) * 100.0 / selling_price), 1) AS avg_margin_pct
FROM     products
GROUP BY category, business_area
ORDER BY avg_margin_pct DESC;

SELECT   p.category,
         p.business_area,
         ROUND(SUM(s.quantity * (s.unit_price - s.unit_cost)) * 100.0
               / SUM(s.quantity * s.unit_price), 1) AS actual_margin_pct
FROM     sales AS s
JOIN     products AS p ON s.product_id = p.product_id
WHERE    s.line_type <> 'Suspicious'
GROUP BY p.category, p.business_area
ORDER BY actual_margin_pct DESC;


-- ---------------------------------------------------------------------
-- 3.6  Basket size: products per receipt (Café ~2.1, Store ~1.6)
-- ---------------------------------------------------------------------
SELECT   p.business_area,
         ROUND(COUNT(*) * 1.0 / COUNT(DISTINCT s.transaction_id), 2) AS avg_products_per_receipt
FROM     sales AS s
JOIN     products AS p ON s.product_id = p.product_id
WHERE    s.line_type = 'Sale'
GROUP BY p.business_area;


-- ---------------------------------------------------------------------
-- 3.7  Supplier costs by year (Valley Dairy and coffee rose fastest)
-- ---------------------------------------------------------------------
SELECT   pu.supplier_id,
         su.supplier_name,
         ROUND(AVG(CASE WHEN YEAR(pu.delivery_week) = 2024 THEN pu.unit_cost END), 2) AS avg_cost_2024,
         ROUND(AVG(CASE WHEN YEAR(pu.delivery_week) = 2025 THEN pu.unit_cost END), 2) AS avg_cost_2025,
         ROUND((AVG(CASE WHEN YEAR(pu.delivery_week) = 2025 THEN pu.unit_cost END)
              - AVG(CASE WHEN YEAR(pu.delivery_week) = 2024 THEN pu.unit_cost END)) * 100.0
              / AVG(CASE WHEN YEAR(pu.delivery_week) = 2024 THEN pu.unit_cost END), 1) AS change_pct
FROM     purchases AS pu
JOIN     suppliers AS su ON pu.supplier_id = su.supplier_id
GROUP BY pu.supplier_id, su.supplier_name
ORDER BY change_pct DESC;


-- ---------------------------------------------------------------------
-- 3.8  Top 5 products by cost of waste
-- ---------------------------------------------------------------------
SELECT   p.product_name,
         ROUND(SUM(w.quantity_wasted * p.cost_price), 2) AS total_waste_cost
FROM     wastage AS w
JOIN     products AS p ON w.product_id = p.product_id
GROUP BY p.product_name
ORDER BY total_waste_cost DESC
LIMIT 5;


-- ---------------------------------------------------------------------
-- 3.9  Café waste cost by day of week (Monday is double other weekdays)
-- ---------------------------------------------------------------------
SELECT   DAYNAME(w.date) AS day_name,
         ROUND(SUM(w.quantity_wasted * p.cost_price), 2) AS total_waste_cost
FROM     wastage AS w
JOIN     products AS p ON w.product_id = p.product_id
WHERE    p.business_area = 'Café'
GROUP BY DAYNAME(w.date)
ORDER BY total_waste_cost DESC;


-- ---------------------------------------------------------------------
-- 3.10 Busiest hours (Café: 1–2 pm and 10–11 am | Store: 5–6 pm and 8 am)
-- ---------------------------------------------------------------------
SELECT   p.business_area,
         HOUR(s.time) AS hour,
         COUNT(DISTINCT s.transaction_id) AS customers
FROM     sales AS s
JOIN     products AS p ON s.product_id = p.product_id
WHERE    s.line_type = 'Sale'
GROUP BY p.business_area, HOUR(s.time)
ORDER BY p.business_area, customers DESC;


-- ---------------------------------------------------------------------
-- 3.11 Café staffing vs customers by day of week
--      Finding: Saturday = most customers, fewest shifts; Tuesday = opposite
-- ---------------------------------------------------------------------
WITH cafe_customers AS (
    SELECT   DAYNAME(s.date) AS day_name,
             COUNT(DISTINCT s.transaction_id) AS customers
    FROM     sales AS s
    JOIN     products AS p ON s.product_id = p.product_id
    WHERE    p.business_area = 'Café'
      AND    s.line_type = 'Sale'
    GROUP BY DAYNAME(s.date)
),
cafe_shifts AS (
    SELECT   DAYNAME(sh.date) AS day_name,
             COUNT(*)        AS shifts,
             SUM(sh.hours)   AS staff_hours
    FROM     shifts AS sh
    JOIN     staff  AS st ON sh.staff_id = st.staff_id
    WHERE    st.business_area = 'Café'
    GROUP BY DAYNAME(sh.date)
)
SELECT   c.day_name,
         c.customers,
         sh.shifts,
         sh.staff_hours,
         ROUND(c.customers * 1.0 / sh.staff_hours, 2) AS customers_per_staff_hour
FROM     cafe_customers AS c
JOIN     cafe_shifts    AS sh ON c.day_name = sh.day_name
ORDER BY customers_per_staff_hour DESC;


-- ---------------------------------------------------------------------
-- 3.12 Weather: average café customers per day by condition
-- ---------------------------------------------------------------------
WITH daily AS (
    SELECT   s.date,
             COUNT(DISTINCT s.transaction_id) AS customers
    FROM     sales AS s
    JOIN     products AS p ON s.product_id = p.product_id
    WHERE    p.business_area = 'Café'
      AND    s.line_type = 'Sale'
    GROUP BY s.date
)
SELECT   w.`condition`,
         COUNT(*)                     AS days,
         ROUND(AVG(d.customers), 2)   AS avg_customers_per_day
FROM     daily   AS d
JOIN     weather AS w ON d.date = w.date
WHERE    w.`condition` <> 'Not recorded'
GROUP BY w.`condition`
ORDER BY avg_customers_per_day DESC;

-- Controlling for season (weather matters in summer, barely in winter)
WITH daily AS (
    SELECT   s.date,
             COUNT(DISTINCT s.transaction_id) AS customers
    FROM     sales AS s
    JOIN     products AS p ON s.product_id = p.product_id
    WHERE    p.business_area = 'Café'
      AND    s.line_type = 'Sale'
    GROUP BY s.date
),
with_season AS (
    SELECT d.customers,
           w.`condition`,
           CASE WHEN MONTH(d.date) IN (12, 1, 2) THEN 'Winter'
                WHEN MONTH(d.date) IN (3, 4, 5)  THEN 'Spring'
                WHEN MONTH(d.date) IN (6, 7, 8)  THEN 'Summer'
                ELSE 'Autumn' END AS season
    FROM   daily   AS d
    JOIN   weather AS w ON d.date = w.date
    WHERE  w.`condition` <> 'Not recorded'
)
SELECT   `condition`,
         ROUND(AVG(CASE WHEN season = 'Winter' THEN customers END), 1) AS winter,
         ROUND(AVG(CASE WHEN season = 'Spring' THEN customers END), 1) AS spring,
         ROUND(AVG(CASE WHEN season = 'Summer' THEN customers END), 1) AS summer,
         ROUND(AVG(CASE WHEN season = 'Autumn' THEN customers END), 1) AS autumn
FROM     with_season
GROUP BY `condition`
ORDER BY summer DESC;


-- ---------------------------------------------------------------------
-- 3.13 Window functions: best-selling product in each business area
--      (Latte in the Café, Coal Bag 20kg in the Store)
-- ---------------------------------------------------------------------
WITH product_revenue AS (
    SELECT   p.product_name,
             p.business_area,
             SUM(s.quantity * s.unit_price) AS revenue
    FROM     sales AS s
    JOIN     products AS p ON s.product_id = p.product_id
    WHERE    s.line_type <> 'Suspicious'
    GROUP BY p.product_name, p.business_area
),
ranked AS (
    SELECT product_name,
           business_area,
           revenue,
           RANK() OVER (PARTITION BY business_area ORDER BY revenue DESC) AS revenue_rank
    FROM   product_revenue
)
SELECT   product_name,
         business_area,
         ROUND(revenue, 2) AS revenue,
         revenue_rank
FROM     ranked
WHERE    revenue_rank <= 3
ORDER BY business_area, revenue_rank;


-- ---------------------------------------------------------------------
-- 3.14 Window functions: each product's share of its area's revenue
-- ---------------------------------------------------------------------
WITH product_revenue AS (
    SELECT   p.product_name,
             p.business_area,
             SUM(s.quantity * s.unit_price) AS revenue
    FROM     sales AS s
    JOIN     products AS p ON s.product_id = p.product_id
    WHERE    s.line_type <> 'Suspicious'
    GROUP BY p.product_name, p.business_area
)
SELECT   product_name,
         business_area,
         ROUND(revenue, 2) AS revenue,
         ROUND(revenue * 100.0 / SUM(revenue) OVER (PARTITION BY business_area), 1) AS pct_of_area
FROM     product_revenue
ORDER BY business_area, pct_of_area DESC;


-- ---------------------------------------------------------------------
-- 3.15 Window functions: store revenue by month in 2025 –
--      previous month (LAG), change, and running total (year to date)
-- ---------------------------------------------------------------------
WITH monthly AS (
    SELECT   MONTH(s.date) AS month,
             SUM(s.quantity * s.unit_price) AS revenue
    FROM     sales AS s
    JOIN     products AS p ON s.product_id = p.product_id
    WHERE    p.business_area = 'Store'
      AND    YEAR(s.date) = 2025
      AND    s.line_type <> 'Suspicious'
    GROUP BY MONTH(s.date)
)
SELECT   month,
         ROUND(revenue, 2)                                       AS revenue,
         ROUND(LAG(revenue) OVER (ORDER BY month), 2)            AS previous_month,
         ROUND(revenue - LAG(revenue) OVER (ORDER BY month), 2)  AS change_vs_prev,
         ROUND(SUM(revenue) OVER (ORDER BY month), 2)            AS running_total
FROM     monthly
ORDER BY month;


-- ---------------------------------------------------------------------
-- 3.16 Data-quality checks (good to show in interviews)
-- ---------------------------------------------------------------------
-- Suspicious quantities kept for investigation (business rule: qty > 10)
SELECT s.*, p.product_name
FROM   sales AS s
JOIN   products AS p ON s.product_id = p.product_id
WHERE  s.line_type = 'Suspicious';

-- Refund value by business area
SELECT   p.business_area,
         COUNT(*) AS refund_lines,
         ROUND(-SUM(s.quantity * s.unit_price), 2) AS refund_value
FROM     sales AS s
JOIN     products AS p ON s.product_id = p.product_id
WHERE    s.line_type = 'Refund'
GROUP BY p.business_area;

-- Sales with no staff recorded (NULLs were replaced with 'Unknown' in cleaning;
-- on raw data you would use  WHERE staff_id IS NULL,  never  = NULL)
SELECT COUNT(*) AS lines_without_staff
FROM   sales
WHERE  staff_id = 'Unknown';

-- Orphan check: every sale should have a matching product (expected: 0)
SELECT COUNT(*) AS sales_without_product
FROM   sales AS s
LEFT JOIN products AS p ON s.product_id = p.product_id
WHERE  p.product_id IS NULL;
