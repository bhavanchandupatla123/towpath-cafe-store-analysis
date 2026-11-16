-- Checks run on the CLEAN data. Every query should return 0.

-- Q1: Sales lines whose product is missing from Products (orphan foreign keys)
SELECT COUNT(*) AS orphan_product_lines
FROM Sales s
LEFT JOIN Products p ON p.product_id = s.product_id
WHERE p.product_id IS NULL;

-- Q2: Sales lines whose staff member is missing from Staff
SELECT COUNT(*) AS orphan_staff_lines
FROM Sales s
LEFT JOIN Staff st ON st.staff_id = s.staff_id
WHERE st.staff_id IS NULL;

-- Q3: Exact duplicate sales lines left after cleaning
SELECT COUNT(*) AS duplicate_groups
FROM (
    SELECT transaction_id, date, time, product_id, quantity, unit_price, payment_method, staff_id
    FROM Sales
    GROUP BY transaction_id, date, time, product_id, quantity, unit_price, payment_method, staff_id
    HAVING COUNT(*) > 1
) AS d;

-- Q4: Missing values in the columns every measure depends on
SELECT SUM(CASE WHEN unit_price IS NULL THEN 1 ELSE 0 END)
     + SUM(CASE WHEN unit_cost  IS NULL THEN 1 ELSE 0 END)
     + SUM(CASE WHEN quantity   IS NULL THEN 1 ELSE 0 END) AS missing_values
FROM Sales;

-- Q5: Sales dates that do not exist in the Date table
SELECT COUNT(*) AS dates_outside_calendar
FROM Sales s
LEFT JOIN Date d ON d.Date = s.date
WHERE d.Date IS NULL;

-- Q6: Payment methods outside the three allowed values
SELECT COUNT(*) AS bad_payment_methods
FROM Sales
WHERE payment_method NOT IN ('Card', 'Cash', 'Contactless');
