# Data dictionary

Tables in `data/clean/towpath_powerbi_data.xlsx`. Currency is GBP.

## Sales

Fact. One row per product line on a till receipt. 76,856 rows.

| Column | Meaning |
|---|---|
| `sales_line_id` | Unique line number (primary key) |
| `transaction_id` | Receipt number. One receipt is one customer visit and can have several lines |
| `date` | Date of sale (joins to Date) |
| `time` | Time of sale, hh:mm |
| `hour` | Hour of sale, 7 to 19 |
| `product_id` | Product sold (joins to Products) |
| `quantity` | Units sold. Negative for refunds |
| `unit_price` | Price charged per unit |
| `payment_method` | Card, Cash or Contactless |
| `staff_id` | Who served (joins to Staff). "Unknown" where the till did not record it |
| `line_type` | Sale, Refund (negative quantity), Zero (quantity 0) or Suspicious (quantity over 10) |
| `unit_cost` | Cost per unit paid at that week's delivery (from Purchases) |

## Products

Dimension. One row per product. 40 rows.

| Column | Meaning |
|---|---|
| `product_id` | Primary key, P001 to P040 |
| `product_name` | Product name |
| `category` | Product category, for example Hot Drinks or Fuel |
| `business_area` | Café or Store |
| `cost_price` | Current cost price (December 2025) |
| `selling_price` | Current selling price (December 2025) |
| `supplier_id` | Supplier (joins to Suppliers) |

## Staff

Dimension. One row per staff member, plus an Unknown row. 10 rows.

| Column | Meaning |
|---|---|
| `staff_id` | Primary key |
| `name` | Staff name (fictional) |
| `role` | Job role |
| `hourly_rate` | Hourly pay. 0 for the owner |
| `business_area` | Café, Store or Both |

## Shifts

Fact. One row per shift worked. 3,342 rows.

| Column | Meaning |
|---|---|
| `shift_id` | Primary key |
| `staff_id` | Who worked (joins to Staff) |
| `date` | Shift date (joins to Date) |
| `start_time` | Start, hh:mm |
| `end_time` | End, hh:mm |
| `hours` | Shift length in hours |

## Wastage

Fact. One row per wastage record. 5,003 rows.

| Column | Meaning |
|---|---|
| `waste_id` | Primary key |
| `date` | Date thrown away (joins to Date) |
| `product_id` | Product wasted (joins to Products) |
| `quantity_wasted` | Units thrown away |
| `reason` | Unsold end of day, Expired, Damaged, Dropped or Not recorded |

## Suppliers

Dimension. One row per supplier. 6 rows.

| Column | Meaning |
|---|---|
| `supplier_id` | Primary key |
| `supplier_name` | Supplier name (fictional) |
| `delivery_cost` | Flat fee per delivery |
| `delivery_days` | Days the supplier delivers |

## Purchases

Fact. One row per product on a weekly delivery. 4,183 rows.

| Column | Meaning |
|---|---|
| `purchase_id` | Primary key |
| `delivery_week` | Monday of the delivery week |
| `supplier_id` | Supplier (joins to Suppliers) |
| `product_id` | Product bought (joins to Products) |
| `quantity` | Units delivered |
| `unit_cost` | Cost per unit paid on that delivery |

## Date

Dimension. One row per day from 1 Jan 2024 to 31 Dec 2025, with weather joined on. 731 rows.

| Column | Meaning |
|---|---|
| `Date` | Primary key |
| `Year` | Calendar year |
| `Quarter` | Q1 to Q4 |
| `MonthNo` | Month number, used to sort Month |
| `Month` | Jan to Dec |
| `YearMonth` | yyyy-mm |
| `WeekStart` | Monday of that week |
| `DayNo` | 1 (Mon) to 7 (Sun), used to sort Day |
| `Day` | Mon to Sun |
| `Season` | Winter (Dec to Feb), Spring, Summer, Autumn |
| `IsWeekend` | Weekday or Weekend |
| `SeasonNo` | Used to sort Season |
| `avg_temp_c` | Average temperature in °C. Blank where the reading was impossible or missing |
| `rainfall_mm` | Rainfall in mm |
| `Weather` | Sunny, Cloudy, Rain, Heavy Rain or Not recorded |
| `WeatherNo` | Used to sort Weather |
