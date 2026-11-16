# SQL results

Produced by `python/03_run_sql.py` (SQLite). Do not edit by hand: re-run the script instead.

## 02_data_quality_checks.sql

**Q1: Sales lines whose product is missing from Products (orphan foreign keys)**

|   orphan_product_lines |
|-----------------------:|
|                      0 |

**Q2: Sales lines whose staff member is missing from Staff**

|   orphan_staff_lines |
|---------------------:|
|                    0 |

**Q3: Exact duplicate sales lines left after cleaning**

|   duplicate_groups |
|-------------------:|
|                  0 |

**Q4: Missing values in the columns every measure depends on**

|   missing_values |
|-----------------:|
|                0 |

**Q5: Sales dates that do not exist in the Date table**

|   dates_outside_calendar |
|-------------------------:|
|                        0 |

**Q6: Payment methods outside the three allowed values**

|   bad_payment_methods |
|----------------------:|
|                     0 |

## 03_business_questions.sql

**Q1: Revenue, customers, average spend and gross margin by year**

|   Year |    revenue |   customers |   avg_spend |   gross_margin_pct |
|-------:|-----------:|------------:|------------:|-------------------:|
|   2024 | 133,993.94 |       20832 |        6.43 |              67.20 |
|   2025 | 141,003.50 |       20890 |        6.75 |              66.90 |

**Q2: Café vs Store, 2025 against 2024 (conditional aggregation)**

| business_area   |   revenue_2024 |   revenue_2025 |   revenue_yoy_pct |   customers_2024 |   customers_2025 |   customers_yoy_pct |
|:----------------|---------------:|---------------:|------------------:|-----------------:|-----------------:|--------------------:|
| Café            |      87,307.80 |      98,175.55 |             12.40 |            10215 |            11437 |               12.00 |
| Store           |      46,686.14 |      42,827.95 |             -8.30 |            10617 |             9453 |              -11.00 |

**Q3: Store customers by month with last year's figure alongside (CTE + LAG window function)**

| Month   |   customers_2024 |   customers_2025 |   yoy_pct |
|:--------|-----------------:|-----------------:|----------:|
| Jan     |              800 |              770 |     -3.70 |
| Feb     |              711 |              662 |     -6.90 |
| Mar     |              848 |              856 |      0.90 |
| Apr     |              866 |              743 |    -14.20 |
| May     |              936 |              818 |    -12.60 |
| Jun     |              962 |              807 |    -16.10 |
| Jul     |             1042 |              920 |    -11.70 |
| Aug     |             1053 |              907 |    -13.90 |
| Sep     |              880 |              777 |    -11.70 |
| Oct     |              858 |              716 |    -16.60 |
| Nov     |              798 |              684 |    -14.30 |
| Dec     |              863 |              793 |     -8.10 |

**Q4: Did store prices change, and when? (months where a product's price differs from the month before)**

| YearMonth   |   products_repriced |   avg_change_pct |
|:------------|--------------------:|-----------------:|
| 2025-01     |                  20 |             3.50 |

**Q5: Top 3 products by revenue in each business area, 2025 (RANK window function)**

| business_area   |   rank_in_area | product_name         |   revenue |
|:----------------|---------------:|:---------------------|----------:|
| Café            |              1 | Latte                |  9,479.20 |
| Café            |              2 | Full Breakfast       |  9,144.05 |
| Café            |              3 | Ham & Cheese Toastie |  7,368.75 |
| Store           |              1 | Coal Bag 20kg        |  8,353.90 |
| Store           |              2 | Kiln Dried Logs      |  4,519.90 |
| Store           |              3 | Gas Canister         |  3,847.05 |

**Q6: Average unit cost change by supplier, 2025 against 2024**

| supplier_name              |   products |   avg_unit_cost_change_pct |
|:---------------------------|-----------:|---------------------------:|
| Valley Dairy Ltd           |          9 |                      19.00 |
| Black Lock Coffee Roasters |          1 |                      10.20 |
| Hillside Bakery            |          6 |                       3.20 |
| Wholesale Direct           |         14 |                       3.10 |
| Fuel & Fire Co             |          4 |                       3.10 |
| Fresh Fields Produce       |          6 |                       3.10 |

**Q7: Categories that lost the most margin in 2025**

| business_area   | category    |   margin_2024_pct |   margin_2025_pct |
|:----------------|:------------|------------------:|------------------:|
| Store           | Dairy       |             35.80 |             25.60 |
| Café            | Cold Treats |             81.70 |             77.80 |
| Café            | Hot Drinks  |             81.40 |             78.20 |
| Café            | Breakfast   |             70.50 |             69.80 |
| Café            | Cold Drinks |             76.30 |             75.60 |

**Q8: Café staffing against demand by day of week (two CTEs joined on the day)**

| Day   |   customers_per_day |   staff_hours_per_day |   customers_per_staff_hour |
|:------|--------------------:|----------------------:|---------------------------:|
| Mon   |               25.60 |                    16 |                       1.60 |
| Tue   |               22.00 |                    24 |                       0.92 |
| Wed   |               23.30 |                    24 |                       0.97 |
| Thu   |               26.00 |                    16 |                       1.63 |
| Fri   |               29.50 |                    24 |                       1.23 |
| Sat   |               42.90 |                    16 |                       2.68 |
| Sun   |               38.10 |                    24 |                       1.59 |

**Q9: Café wastage by day of week (units and cost per trading day)**

| Day   |   units_per_day |   cost_per_day |
|:------|----------------:|---------------:|
| Mon   |           20.00 |          14.12 |
| Tue   |            9.20 |           6.75 |
| Wed   |            9.20 |           6.68 |
| Thu   |            9.80 |           7.10 |
| Fri   |           10.10 |           7.22 |
| Sat   |           13.00 |           9.30 |
| Sun   |           12.20 |           8.75 |

**Q10: Monthly revenue in 2025 with a running total (SUM window function)**

| Month   |   revenue |   running_total |
|:--------|----------:|----------------:|
| Jan     |  9,273.35 |        9,273.35 |
| Feb     |  7,941.05 |       17,214.40 |
| Mar     | 10,519.10 |       27,733.50 |
| Apr     | 10,735.95 |       38,469.45 |
| May     | 12,680.10 |       51,149.55 |
| Jun     | 14,218.20 |       65,367.75 |
| Jul     | 16,426.15 |       81,793.90 |
| Aug     | 17,887.40 |       99,681.30 |
| Sep     | 12,250.15 |      111,931.45 |
| Oct     | 10,211.60 |      122,143.05 |
| Nov     |  8,799.85 |      130,942.90 |
| Dec     | 10,060.60 |      141,003.50 |

**Q11: Average café revenue per day by season and weather**

| Season   |   sunny |   cloudy |   rain |   heavy_rain |
|:---------|--------:|---------:|-------:|-------------:|
| Winter   |     151 |      176 |    156 |          145 |
| Spring   |     260 |      270 |    219 |          191 |
| Summer   |     458 |      358 |    351 |          317 |
| Autumn   |     248 |      248 |    215 |          196 |
