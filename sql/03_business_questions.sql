-- The Towpath: business questions
-- Rule used everywhere: line_type <> 'Suspicious' (six keying errors are excluded, as in Power BI).
-- Revenue = quantity * unit_price (refunds included as negatives).
-- Customers = distinct receipts that contain at least one normal 'Sale' line.

-- Q1: Revenue, customers, average spend and gross margin by year
SELECT d.Year,
       ROUND(SUM(s.quantity * s.unit_price), 2)                                   AS revenue,
       COUNT(DISTINCT CASE WHEN s.line_type = 'Sale' THEN s.transaction_id END)                                           AS customers,
       ROUND(SUM(s.quantity * s.unit_price) / COUNT(DISTINCT CASE WHEN s.line_type = 'Sale' THEN s.transaction_id END), 2) AS avg_spend,
       ROUND(100.0 * SUM(s.quantity * (s.unit_price - s.unit_cost))
                   / SUM(s.quantity * s.unit_price), 1)                           AS gross_margin_pct
FROM Sales s
JOIN Date d ON d.Date = s.date
WHERE s.line_type <> 'Suspicious'
GROUP BY d.Year
ORDER BY d.Year;

-- Q2: Café vs Store, 2025 against 2024 (conditional aggregation)
SELECT p.business_area,
       ROUND(SUM(CASE WHEN d.Year = 2024 THEN s.quantity * s.unit_price END), 2) AS revenue_2024,
       ROUND(SUM(CASE WHEN d.Year = 2025 THEN s.quantity * s.unit_price END), 2) AS revenue_2025,
       ROUND(100.0 * (SUM(CASE WHEN d.Year = 2025 THEN s.quantity * s.unit_price END)
                    / SUM(CASE WHEN d.Year = 2024 THEN s.quantity * s.unit_price END) - 1), 1) AS revenue_yoy_pct,
       COUNT(DISTINCT CASE WHEN d.Year = 2024 AND s.line_type = 'Sale' THEN s.transaction_id END) AS customers_2024,
       COUNT(DISTINCT CASE WHEN d.Year = 2025 AND s.line_type = 'Sale' THEN s.transaction_id END) AS customers_2025,
       ROUND(100.0 * (1.0 * COUNT(DISTINCT CASE WHEN d.Year = 2025 AND s.line_type = 'Sale' THEN s.transaction_id END)
                          / COUNT(DISTINCT CASE WHEN d.Year = 2024 AND s.line_type = 'Sale' THEN s.transaction_id END) - 1), 1) AS customers_yoy_pct
FROM Sales s
JOIN Products p ON p.product_id = s.product_id
JOIN Date d     ON d.Date = s.date
WHERE s.line_type <> 'Suspicious'
GROUP BY p.business_area;

-- Q3: Store customers by month with last year's figure alongside (CTE + LAG window function)
WITH monthly AS (
    SELECT d.Year, d.MonthNo, d.Month,
           COUNT(DISTINCT CASE WHEN s.line_type = 'Sale' THEN s.transaction_id END) AS customers
    FROM Sales s
    JOIN Products p ON p.product_id = s.product_id
    JOIN Date d     ON d.Date = s.date
    WHERE p.business_area = 'Store' AND s.line_type <> 'Suspicious'
    GROUP BY d.Year, d.MonthNo, d.Month
),
with_last_year AS (
    SELECT Year, MonthNo, Month, customers,
           LAG(customers) OVER (PARTITION BY MonthNo ORDER BY Year) AS customers_last_year
    FROM monthly
)
SELECT Month, customers_last_year AS customers_2024, customers AS customers_2025,
       ROUND(100.0 * (1.0 * customers / customers_last_year - 1), 1) AS yoy_pct
FROM with_last_year
WHERE Year = 2025
ORDER BY MonthNo;

-- Q4: Did store prices change, and when? (months where a product's price differs from the month before)
WITH monthly_price AS (
    SELECT d.YearMonth, s.product_id, MAX(s.unit_price) AS price
    FROM Sales s
    JOIN Products p ON p.product_id = s.product_id
    JOIN Date d     ON d.Date = s.date
    WHERE p.business_area = 'Store' AND s.line_type = 'Sale'
    GROUP BY d.YearMonth, s.product_id
),
changes AS (
    SELECT YearMonth, product_id, price,
           LAG(price) OVER (PARTITION BY product_id ORDER BY YearMonth) AS previous_price
    FROM monthly_price
)
SELECT YearMonth,
       COUNT(*)                                             AS products_repriced,
       ROUND(100.0 * AVG(price / previous_price - 1), 1)    AS avg_change_pct
FROM changes
WHERE price <> previous_price
GROUP BY YearMonth
ORDER BY YearMonth;

-- Q5: Top 3 products by revenue in each business area, 2025 (RANK window function)
WITH product_revenue AS (
    SELECT p.business_area, p.product_name,
           ROUND(SUM(s.quantity * s.unit_price), 2) AS revenue
    FROM Sales s
    JOIN Products p ON p.product_id = s.product_id
    JOIN Date d     ON d.Date = s.date
    WHERE d.Year = 2025 AND s.line_type <> 'Suspicious'
    GROUP BY p.business_area, p.product_name
),
ranked AS (
    SELECT business_area, product_name, revenue,
           RANK() OVER (PARTITION BY business_area ORDER BY revenue DESC) AS rank_in_area
    FROM product_revenue
)
SELECT business_area, rank_in_area, product_name, revenue
FROM ranked
WHERE rank_in_area <= 3
ORDER BY business_area, rank_in_area;

-- Q6: Average unit cost change by supplier, 2025 against 2024
WITH product_cost AS (
    SELECT supplier_id, product_id,
           AVG(CASE WHEN delivery_week <  '2025-01-01' THEN unit_cost END) AS cost_2024,
           AVG(CASE WHEN delivery_week >= '2025-01-01' THEN unit_cost END) AS cost_2025
    FROM Purchases
    GROUP BY supplier_id, product_id
)
SELECT su.supplier_name,
       COUNT(*)                                                 AS products,
       ROUND(100.0 * AVG(pc.cost_2025 / pc.cost_2024 - 1), 1)   AS avg_unit_cost_change_pct
FROM product_cost pc
JOIN Suppliers su ON su.supplier_id = pc.supplier_id
GROUP BY su.supplier_name
ORDER BY avg_unit_cost_change_pct DESC;

-- Q7: Categories that lost the most margin in 2025
SELECT p.business_area, p.category,
       ROUND(100.0 * SUM(CASE WHEN d.Year = 2024 THEN s.quantity * (s.unit_price - s.unit_cost) END)
                   / SUM(CASE WHEN d.Year = 2024 THEN s.quantity * s.unit_price END), 1) AS margin_2024_pct,
       ROUND(100.0 * SUM(CASE WHEN d.Year = 2025 THEN s.quantity * (s.unit_price - s.unit_cost) END)
                   / SUM(CASE WHEN d.Year = 2025 THEN s.quantity * s.unit_price END), 1) AS margin_2025_pct
FROM Sales s
JOIN Products p ON p.product_id = s.product_id
JOIN Date d     ON d.Date = s.date
WHERE s.line_type <> 'Suspicious'
GROUP BY p.business_area, p.category
ORDER BY (margin_2025_pct - margin_2024_pct)
LIMIT 5;

-- Q8: Café staffing against demand by day of week (two CTEs joined on the day)
WITH day_count AS (
    SELECT DayNo, Day, COUNT(*) AS days FROM Date GROUP BY DayNo, Day
),
demand AS (
    SELECT d.DayNo, COUNT(DISTINCT CASE WHEN s.line_type = 'Sale' THEN s.transaction_id END) AS customers
    FROM Sales s
    JOIN Products p ON p.product_id = s.product_id
    JOIN Date d     ON d.Date = s.date
    WHERE p.business_area = 'Café' AND s.line_type <> 'Suspicious'
    GROUP BY d.DayNo
),
rota AS (
    SELECT d.DayNo, SUM(sh.hours) AS staff_hours
    FROM Shifts sh
    JOIN Staff st ON st.staff_id = sh.staff_id
    JOIN Date d   ON d.Date = sh.date
    WHERE st.business_area = 'Café'
    GROUP BY d.DayNo
)
SELECT dc.Day,
       ROUND(1.0 * dm.customers / dc.days, 1)      AS customers_per_day,
       ROUND(r.staff_hours / dc.days, 1)           AS staff_hours_per_day,
       ROUND(dm.customers / r.staff_hours, 2)      AS customers_per_staff_hour
FROM day_count dc
JOIN demand dm ON dm.DayNo = dc.DayNo
JOIN rota r    ON r.DayNo  = dc.DayNo
ORDER BY dc.DayNo;

-- Q9: Café wastage by day of week (units and cost per trading day)
SELECT d.Day,
       ROUND(1.0 * SUM(w.quantity_wasted) / (SELECT COUNT(*) FROM Date x WHERE x.DayNo = d.DayNo), 1) AS units_per_day,
       ROUND(SUM(w.quantity_wasted * p.cost_price) / (SELECT COUNT(*) FROM Date x WHERE x.DayNo = d.DayNo), 2) AS cost_per_day
FROM Wastage w
JOIN Products p ON p.product_id = w.product_id
JOIN Date d     ON d.Date = w.date
WHERE p.business_area = 'Café'
GROUP BY d.DayNo, d.Day
ORDER BY d.DayNo;

-- Q10: Monthly revenue in 2025 with a running total (SUM window function)
WITH monthly AS (
    SELECT d.MonthNo, d.Month, SUM(s.quantity * s.unit_price) AS revenue
    FROM Sales s
    JOIN Date d ON d.Date = s.date
    WHERE d.Year = 2025 AND s.line_type <> 'Suspicious'
    GROUP BY d.MonthNo, d.Month
)
SELECT Month,
       ROUND(revenue, 2)                               AS revenue,
       ROUND(SUM(revenue) OVER (ORDER BY MonthNo), 2)  AS running_total
FROM monthly
ORDER BY MonthNo;

-- Q11: Average café revenue per day by season and weather
WITH daily AS (
    SELECT d.Date, d.SeasonNo, d.Season, d.Weather, SUM(s.quantity * s.unit_price) AS revenue
    FROM Sales s
    JOIN Products p ON p.product_id = s.product_id
    JOIN Date d     ON d.Date = s.date
    WHERE p.business_area = 'Café' AND s.line_type <> 'Suspicious' AND d.Weather <> 'Not recorded'
    GROUP BY d.Date, d.SeasonNo, d.Season, d.Weather
)
SELECT Season,
       ROUND(AVG(CASE WHEN Weather = 'Sunny'      THEN revenue END), 0) AS sunny,
       ROUND(AVG(CASE WHEN Weather = 'Cloudy'     THEN revenue END), 0) AS cloudy,
       ROUND(AVG(CASE WHEN Weather = 'Rain'       THEN revenue END), 0) AS rain,
       ROUND(AVG(CASE WHEN Weather = 'Heavy Rain' THEN revenue END), 0) AS heavy_rain
FROM daily
GROUP BY SeasonNo, Season
ORDER BY SeasonNo;
