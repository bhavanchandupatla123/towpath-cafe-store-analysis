# The Towpath in MySQL

`towpath_mysql.sql` is a MySQL 8 version of the project's SQL work. One script builds the database, loads the clean data and answers the business questions.

The SQLite files one level up (`sql/01_schema.sql` to `03_business_questions.sql`) are run automatically by `python/03_run_sql.py`. This folder is for running the same analysis in MySQL Workbench.

## What the script does

| Part | Contents |
|---|---|
| 1. Schema | 8 tables with primary and foreign keys: `sales`, `wastage`, `shifts`, `purchases` (facts) and `products`, `suppliers`, `staff`, `weather` (dimensions) |
| 2. Load | `LOAD DATA LOCAL INFILE` from the 8 CSV files in `data/clean/csv/` |
| 3. Analysis | 17 queries: revenue and YoY by business area, store customers and spend, monthly customers per day, margin by category, basket size, supplier costs, waste by product and day, busiest hours, staffing against demand, weather by season, window functions (`RANK`, `SUM() OVER`, `LAG`, running total) and data-quality checks |

## Run it

1. Copy `data/clean/csv/` to `C:/Towpath/csv/`, or edit the paths in Part 2.
2. In MySQL Workbench, allow file loading once:
   - run `SET GLOBAL local_infile = 1;`
   - **Database → Manage Connections → your connection → Advanced**, and add `OPT_LOCAL_INFILE=1` in the **Others** box
   - close and reopen the connection
3. Open `towpath_mysql.sql` and run Parts 1 and 2.
4. Run query 3.0. The row counts should be: sales 76,856 · products 40 · staff 10 · shifts 3,342 · wastage 5,003 · suppliers 6 · purchases 4,183 · weather 731.
5. Run the Part 3 queries one at a time.

## Checks

These use the same business rules as Power BI and the SQLite queries, and return the same numbers:

| Query | Result |
|---|---|
| Total revenue | £274,997.44 |
| Café revenue, 2025 vs 2024 | +12.4% |
| Store revenue, 2025 vs 2024 | −8.3% |
| Store customers, 2025 vs 2024 | 10,617 → 9,453 (−11.0%) |
| Top product by revenue | Latte (Café), Coal Bag 20kg (Store) |
