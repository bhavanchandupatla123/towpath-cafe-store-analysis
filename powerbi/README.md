# Power BI dashboard

The dashboard reads `data/clean/towpath_powerbi_data.xlsx`, the workbook produced by `python/01_clean_data.py`. Nothing is cleaned inside Power BI, so the dashboard, the SQL and the notebook all start from the same data.

## Data model

A star schema with a dedicated Date table (marked as the date table, so time intelligence works).

| Table | Type | Rows | Grain |
|---|---|---:|---|
| Sales | Fact | 76,856 | One product line on a till receipt |
| Shifts | Fact | 3,342 | One staff shift |
| Wastage | Fact | 5,003 | One wastage record |
| Purchases | Fact | 4,183 | One product on a weekly delivery |
| Products | Dimension | 40 | One product |
| Staff | Dimension | 10 | One staff member, plus an "Unknown" row |
| Suppliers | Dimension | 6 | One supplier |
| Date | Dimension | 731 | One day, with season and weather |

Main relationships (one to many, single direction, dimension filters fact):

- `Products[product_id]` → `Sales`, `Wastage`, `Purchases`
- `Date[Date]` → `Sales[date]`, `Shifts[date]`, `Wastage[date]`
- `Staff[staff_id]` → `Sales`, `Shifts`
- `Suppliers[supplier_id]` → `Products`, `Purchases`

Sort-by columns keep text in the right order: `Month` by `MonthNo`, `Day` by `DayNo`, `Season` by `SeasonNo`, `Weather` by `WeatherNo`.

## Measures

All 39 measures are in [measures.dax](measures.dax), grouped into display folders (Sales, Profit, Time, Waste, Staffing, Store, Café).

The ones that carry the analysis:

| Measure | Why it is written this way |
|---|---|
| `Total Revenue` | `SUMX` over quantity × unit price, row by row, because price varies by line. Suspicious lines are filtered out |
| `Total Customers` | `DISTINCTCOUNT` of receipts, because one receipt has several lines. Counting rows would overstate customers |
| `Gross Margin %` | Uses `unit_cost` on each sale (the cost at that week's delivery), so supplier cost rises show up in margin |
| `Revenue LY`, `Revenue YoY %` | `CALCULATE` with `SAMEPERIODLASTYEAR`, with `DIVIDE` to avoid divide-by-zero errors |
| `Store Customers YoY %` | The measure behind the April 2025 finding |
| `Customers per Staff Hour` | Demand against rota, the measure behind the Saturday staffing finding |

## Report pages

| Page | Question it answers | Main visuals |
|---|---|---|
| Overview | How is the business doing? | Area and year slicers, KPI cards, revenue by month against last year, revenue and margin by category |
| Store investigation | When and why did the store slow down? | Weekly customers 2025 against 2024, showing the April drop |
| Café operations | When is the café busy, and is it staffed for it? | Day by hour heatmap, customers against staff hours, waste |
| Weather & seasons | Does weather change trade? | Season by weather matrix, summer chart |

## Check the dashboard against the code

Select **2025** on the Overview page. The cards should show:

| Card | Value |
|---|---:|
| Total Revenue | £141,004 |
| Revenue YoY % | +5.2% |
| Gross Margin % | 66.9% |
| Total Customers | 20,890 |

These match `outputs/key_numbers.csv` and Q1 in `outputs/sql_results.md`.

## Open it

1. Open the `.pbix` file in Power BI Desktop.
2. If the data does not load, go to **Transform data → Data source settings → Change source** and point it at `data/clean/towpath_powerbi_data.xlsx` in your copy of this repository.
3. Click **Refresh**.
