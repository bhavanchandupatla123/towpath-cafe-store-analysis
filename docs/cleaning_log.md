# Cleaning log

Every change made between `data/raw/towpath_raw_data.xlsx` and `data/clean/towpath_powerbi_data.xlsx`.
The same log is stored in the `Cleaning_Log` sheet of the clean workbook, and `python/01_clean_data.py` regenerates it.

## Order of cleaning

1. Remove exact duplicates first, so later counts and medians are not distorted.
2. Fix formats (dates, prices, IDs, text case) so that columns have one data type.
3. Standardise categories (business area, payment method, wastage reason, weather).
4. Handle missing values last, because a good fill value depends on clean data.
5. Flag unusual values instead of deleting them.

## Changes

| Table     | Action                                                                                                                                      | Rows affected                      |
|:----------|:--------------------------------------------------------------------------------------------------------------------------------------------|:-----------------------------------|
| Sales     | Removed exact duplicate rows                                                                                                                | 922                                |
| Sales     | Added unit_cost = cost paid at that week's delivery (from Purchases)                                                                        | all rows                           |
| Sales     | Trimmed and upper-cased product_id                                                                                                          | all rows                           |
| Sales     | Converted text dates (dd/mm/yyyy, yyyy.mm.dd) to real dates                                                                                 | all rows                           |
| Sales     | Removed £ from text prices and converted to numbers                                                                                         | all rows                           |
| Sales     | Filled missing unit_price with that product's median price in the same month                                                                | 614                                |
| Sales     | Standardised payment_method (trim + Proper case)                                                                                            | all rows                           |
| Sales     | Missing staff_id set to "Unknown"                                                                                                           | 768                                |
| Sales     | Flagged quantity > 10 as "Suspicious" (kept, excluded in measures)                                                                          | 6                                  |
| Sales     | Flagged negative quantity as "Refund" (kept)                                                                                                | 115                                |
| Sales     | Flagged zero quantity as "Zero" (kept, no effect on revenue)                                                                                | 30                                 |
| Products  | Removed duplicate product row (P022)                                                                                                        | 1                                  |
| Products  | Standardised business_area (Cafe/cafe/CAFE/Shop) to Café / Store                                                                            | all rows                           |
| Products  | Trimmed and fixed capitals in product_name; corrected 2 names that did not match their product ID (P005 Pot of Tea, P016 Chocolate Brownie) | all rows                           |
| Products  | Filled 2 missing categories from product type                                                                                               | 2                                  |
| Products  | Converted £ text prices to numbers                                                                                                          | 2                                  |
| Staff     | Fixed name capitals, standardised business_area, filled missing hourly rate (role rate)                                                     | 3 kinds of fix across 4 staff rows |
| Staff     | Added an "Unknown" staff row for sales with no staff recorded                                                                               | 1                                  |
| Shifts    | Converted text dates; swapped start/end times entered the wrong way round                                                                   | 3                                  |
| Wastage   | Standardised reason text; blank reasons set to "Not recorded"; IDs upper-cased                                                              | all rows                           |
| Weather   | Standardised condition text; impossible temps (99.9, -40) and negative rain set to blank                                                    | 3                                  |
| Weather   | Added missing dates so every day exists (condition "Not recorded"); weather columns joined onto the Date table                              | 12                                 |
| Purchases | Filled missing unit_cost with that product's median cost in the same year                                                                   | 15                                 |

## Row counts

| Table | Raw rows | Clean rows | Difference |
|---|---:|---:|---|
| Sales | 77,778 | 76,856 | 922 exact duplicates removed |
| Products | 41 | 40 | 1 duplicate product removed |
| Suppliers | 6 | 6 | none |
| Purchases | 4,183 | 4,183 | none |
| Staff | 9 | 10 | "Unknown" row added |
| Shifts | 3,342 | 3,342 | none |
| Wastage | 5,003 | 5,003 | none |
| Weather | 719 | 731 | 12 missing days added (now part of the Date table) |

## Data quality dimensions covered

| Dimension | Example in this data |
|---|---|
| Completeness | Missing unit prices, staff IDs, wastage reasons, weather days |
| Uniqueness | Duplicate sales lines, duplicate product row |
| Validity | Temperatures of 99.9°C and −40°C, negative rainfall, quantity of 200 on one line |
| Consistency | `Cafe` / `cafe` / `CAFE`, 13 spellings of 3 payment methods |
| Accuracy | Product names that did not match their ID |
| Format | Dates and prices stored as text |
