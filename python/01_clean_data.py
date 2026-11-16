"""
01_clean_data.py
----------------
Turns the raw till / rota / supplier export into the clean star-schema workbook
that the Power BI dashboard reads.

    input : data/raw/towpath_raw_data.xlsx      (8 messy sheets)
    output: data/clean/towpath_powerbi_data.xlsx (7 clean tables + Date table + Cleaning_Log)

Every fix is counted and written to the Cleaning_Log sheet, so anyone can see
exactly what was changed and how many rows it touched.

Run:  python python/01_clean_data.py            (rebuilds the clean workbook)
      python python/01_clean_data.py --check    (rebuilds in memory and compares
                                                 with the saved workbook - no write)
"""
from pathlib import Path
import sys

import numpy as np
import pandas as pd

ROOT = Path(__file__).resolve().parents[1]
RAW = ROOT / "data" / "raw" / "towpath_raw_data.xlsx"
CLEAN = ROOT / "data" / "clean" / "towpath_powerbi_data.xlsx"

log = []  # (table, action, rows_affected)


def note(table, action, rows):
    log.append((table, action, rows))


def to_date(col):
    """Real dates are mixed with text dates typed as dd/mm/yyyy or yyyy.mm.dd."""
    def one(v):
        if isinstance(v, str):
            v = v.strip()
            fmt = "%Y.%m.%d" if "." in v else "%d/%m/%Y"
            return pd.to_datetime(v, format=fmt)
        return pd.to_datetime(v)
    return col.map(one)


def to_number(col):
    """Prices are mostly numbers, but some were typed as text like '£1.40'."""
    return pd.to_numeric(col.astype(str).str.replace("£", "").str.strip(), errors="coerce")


def area(col):
    """Cafe / cafe / CAFE -> Café,  Shop / shop / store -> Store."""
    key = col.str.strip().str.lower().str.replace("é", "e")
    return key.map({"cafe": "Café", "shop": "Store", "store": "Store", "both": "Both"})


def build():
    raw = pd.read_excel(RAW, sheet_name=None)

    # ------------------------------------------------------------ Purchases
    purchases = raw["Purchases"].copy()
    purchases["year"] = purchases["delivery_week"].dt.year
    missing = purchases["unit_cost"].isna()
    median_cost = purchases.groupby(["product_id", "year"])["unit_cost"].transform("median")
    purchases.loc[missing, "unit_cost"] = median_cost[missing].round(2)
    purchases = purchases.drop(columns="year")
    note("Purchases", "Filled missing unit_cost with that product's median cost in the same year", int(missing.sum()))

    # ------------------------------------------------------------ Products
    products = raw["Products"].copy()
    before = len(products)
    products = products.drop_duplicates(subset="product_id").reset_index(drop=True)
    products["business_area"] = area(products["business_area"])
    products["product_name"] = products["product_name"].str.strip()
    products.loc[products["product_id"] == "P027", "product_name"] = "Chocolate Bar"
    # Two names did not match their product ID (copy-paste errors in the product list)
    products.loc[products["product_id"] == "P005", "product_name"] = "Pot of Tea"
    products.loc[products["product_id"] == "P016", "product_name"] = "Chocolate Brownie"
    missing_cat = int(products["category"].isna().sum())
    products.loc[products["product_id"] == "P019", "category"] = "Cold Treats"
    products.loc[products["product_id"] == "P034", "category"] = "Fuel"
    text_prices = int(sum(products[c].map(lambda v: isinstance(v, str)).sum() for c in ["cost_price", "selling_price"]))
    products["cost_price"] = to_number(products["cost_price"])
    products["selling_price"] = to_number(products["selling_price"])
    note("Products", "Removed duplicate product row (P022)", before - len(products))
    note("Products", "Standardised business_area (Cafe/cafe/CAFE/Shop) to Café / Store", "all rows")
    note("Products", "Trimmed and fixed capitals in product_name; corrected 2 names that did not match "
                     "their product ID (P005 Pot of Tea, P016 Chocolate Brownie)", "all rows")
    note("Products", "Filled 2 missing categories from product type", missing_cat)
    note("Products", "Converted £ text prices to numbers", text_prices)

    # ------------------------------------------------------------ Sales
    sales = raw["Sales"].copy()
    before = len(sales)
    sales = sales.drop_duplicates().reset_index(drop=True)
    note("Sales", "Removed exact duplicate rows", before - len(sales))

    sales["product_id"] = sales["product_id"].str.strip().str.upper()
    sales["date"] = to_date(sales["date"])
    sales["unit_price"] = to_number(sales["unit_price"])
    sales["payment_method"] = sales["payment_method"].str.strip().str.title()
    sales["hour"] = sales["time"].str[:2].astype(int)

    # Missing price -> median price of that product in the same month
    missing = sales["unit_price"].isna()
    month = sales["date"].dt.to_period("M")
    median_price = sales.groupby(["product_id", month])["unit_price"].transform("median")
    sales.loc[missing, "unit_price"] = median_price[missing]

    no_staff = sales["staff_id"].isna()
    sales["staff_id"] = sales["staff_id"].fillna("Unknown")

    # Odd quantities are kept but labelled, so measures can include or exclude them
    sales["line_type"] = np.select(
        [sales["quantity"] > 10, sales["quantity"] < 0, sales["quantity"] == 0],
        ["Suspicious", "Refund", "Zero"],
        default="Sale",
    )

    # Cost of each sale = what was paid for that product at that week's delivery
    week = sales["date"] - pd.to_timedelta(sales["date"].dt.weekday, unit="D")
    cost_lookup = purchases.set_index(["delivery_week", "product_id"])["unit_cost"]
    sales["unit_cost"] = pd.MultiIndex.from_arrays([week, sales["product_id"]]).map(cost_lookup)

    sales.insert(0, "sales_line_id", range(1, len(sales) + 1))
    sales = sales[["sales_line_id", "transaction_id", "date", "time", "hour", "product_id", "quantity",
                   "unit_price", "payment_method", "staff_id", "line_type", "unit_cost"]]

    note("Sales", "Added unit_cost = cost paid at that week's delivery (from Purchases)", "all rows")
    note("Sales", "Trimmed and upper-cased product_id", "all rows")
    note("Sales", "Converted text dates (dd/mm/yyyy, yyyy.mm.dd) to real dates", "all rows")
    note("Sales", "Removed £ from text prices and converted to numbers", "all rows")
    note("Sales", "Filled missing unit_price with that product's median price in the same month", int(missing.sum()))
    note("Sales", "Standardised payment_method (trim + Proper case)", "all rows")
    note("Sales", 'Missing staff_id set to "Unknown"', int(no_staff.sum()))
    note("Sales", 'Flagged quantity > 10 as "Suspicious" (kept, excluded in measures)', int((sales["line_type"] == "Suspicious").sum()))
    note("Sales", 'Flagged negative quantity as "Refund" (kept)', int((sales["line_type"] == "Refund").sum()))
    note("Sales", 'Flagged zero quantity as "Zero" (kept, no effect on revenue)', int((sales["line_type"] == "Zero").sum()))

    # ------------------------------------------------------------ Staff
    staff = raw["Staff"].copy()
    fixed = int((staff["name"] != staff["name"].str.title()).sum()
                + (staff["business_area"] != area(staff["business_area"])).sum()
                + staff["hourly_rate"].isna().sum())
    staff["name"] = staff["name"].str.strip().str.title()
    staff["business_area"] = area(staff["business_area"])
    role_rate = staff.groupby("role")["hourly_rate"].transform("median")   # same role, same pay
    staff["hourly_rate"] = pd.to_numeric(staff["hourly_rate"]).fillna(role_rate)
    staff.loc[len(staff)] = ["Unknown", "Not recorded", "Unknown", 0.0, "Unknown"]
    note("Staff", "Fixed name capitals, standardised business_area, filled missing hourly rate (role rate)", fixed)
    note("Staff", 'Added an "Unknown" staff row for sales with no staff recorded', 1)

    # ------------------------------------------------------------ Shifts
    shifts = raw["Shifts"].copy()
    shifts["date"] = to_date(shifts["date"])
    start = pd.to_timedelta(shifts["start_time"] + ":00")
    end = pd.to_timedelta(shifts["end_time"] + ":00")
    swapped = end < start
    shifts.loc[swapped, ["start_time", "end_time"]] = shifts.loc[swapped, ["end_time", "start_time"]].values
    shifts["hours"] = (end - start).abs().dt.total_seconds() / 3600
    note("Shifts", "Converted text dates; swapped start/end times entered the wrong way round", int(swapped.sum()))

    # ------------------------------------------------------------ Wastage
    wastage = raw["Wastage"].copy()
    wastage["waste_id"] = wastage["waste_id"].str.strip().str.upper()
    wastage["product_id"] = wastage["product_id"].str.strip().str.upper()
    reason_map = {
        "unsold end of day": "Unsold end of day", "end of day": "Unsold end of day",
        "unsold eod": "Unsold end of day", "unsold": "Unsold end of day",
        "expired": "Expired", "out of date": "Expired",
        "damaged": "Damaged", "dropped": "Dropped",
    }
    wastage["reason"] = wastage["reason"].str.strip().str.lower().map(reason_map).fillna("Not recorded")
    note("Wastage", 'Standardised reason text; blank reasons set to "Not recorded"; IDs upper-cased', "all rows")

    # ------------------------------------------------------------ Weather -> Date table
    weather = raw["Weather"].copy()
    weather["Weather"] = weather["condition"].str.strip().str.lower().map(
        {"sunny": "Sunny", "cloudy": "Cloudy", "rain": "Rain", "rainy": "Rain", "heavy rain": "Heavy Rain"})
    bad_temp = ~weather["avg_temp_c"].between(-20, 45)      # 99.9 and -40 are sensor errors
    bad_rain = weather["rainfall_mm"] < 0
    weather.loc[bad_temp, "avg_temp_c"] = np.nan
    weather.loc[bad_rain, "rainfall_mm"] = np.nan
    note("Weather", "Standardised condition text; impossible temps (99.9, -40) and negative rain set to blank",
         int(bad_temp.sum() + bad_rain.sum()))

    date = pd.DataFrame({"Date": pd.date_range("2024-01-01", "2025-12-31", freq="D")})
    d = date["Date"]
    date["Year"] = d.dt.year
    date["Quarter"] = "Q" + d.dt.quarter.astype(str)
    date["MonthNo"] = d.dt.month
    date["Month"] = d.dt.strftime("%b")
    date["YearMonth"] = d.dt.strftime("%Y-%m")
    date["WeekStart"] = d - pd.to_timedelta(d.dt.weekday, unit="D")
    date["DayNo"] = d.dt.weekday + 1
    date["Day"] = d.dt.strftime("%a")
    season_no = d.dt.month.map({12: 1, 1: 1, 2: 1, 3: 2, 4: 2, 5: 2, 6: 3, 7: 3, 8: 3, 9: 4, 10: 4, 11: 4})
    date["Season"] = season_no.map({1: "Winter", 2: "Spring", 3: "Summer", 4: "Autumn"})
    date["IsWeekend"] = np.where(d.dt.weekday >= 5, "Weekend", "Weekday")
    date["SeasonNo"] = season_no
    date = date.merge(weather[["date", "avg_temp_c", "rainfall_mm", "Weather"]],
                      left_on="Date", right_on="date", how="left").drop(columns="date")
    no_weather = int(date["Weather"].isna().sum())
    date["Weather"] = date["Weather"].fillna("Not recorded")
    date["WeatherNo"] = date["Weather"].map({"Sunny": 1, "Cloudy": 2, "Rain": 3, "Heavy Rain": 4, "Not recorded": 5})
    note("Weather", 'Added missing dates so every day exists (condition "Not recorded"); '
                    "weather columns joined onto the Date table", no_weather)

    # Log order: Sales first (the fact table), then the dimensions
    order = ["Sales", "Products", "Staff", "Shifts", "Wastage", "Weather", "Purchases"]
    cleaning_log = pd.DataFrame(log, columns=["table", "action", "rows_affected"])
    cleaning_log["_o"] = cleaning_log["table"].map(order.index)
    cleaning_log = cleaning_log.sort_values("_o", kind="stable").drop(columns="_o").reset_index(drop=True)

    return {
        "Sales": sales, "Products": products, "Staff": staff, "Shifts": shifts, "Wastage": wastage,
        "Suppliers": raw["Suppliers"].copy(), "Purchases": purchases, "Date": date, "Cleaning_Log": cleaning_log,
    }


def check(tables):
    """Compare the rebuilt tables with the saved workbook that Power BI reads."""
    saved = pd.read_excel(CLEAN, sheet_name=None)
    ok = True
    for name, new in tables.items():
        if name == "Cleaning_Log":          # the log describes the fixes; the data tables are what must match
            continue
        old = saved[name]
        same = list(new.columns) == list(old.columns) and len(new) == len(old)
        if same:
            for c in new.columns:
                a, b = new[c].reset_index(drop=True), old[c].reset_index(drop=True)
                if pd.api.types.is_numeric_dtype(a) and pd.api.types.is_numeric_dtype(b):
                    col_ok = np.allclose(a.astype(float), b.astype(float), atol=0.005, equal_nan=True)
                else:
                    col_ok = (a.astype(str) == b.astype(str)).all()
                if not col_ok:
                    same = False
                    print(f"   column differs: {name}.{c}")
        print(f"{'MATCH   ' if same else 'DIFFERENT'} {name:<13} {len(new):>6} rows")
        ok &= same
    return ok


if __name__ == "__main__":
    tables = build()
    if "--check" in sys.argv:
        sys.exit(0 if check(tables) else 1)
    with pd.ExcelWriter(CLEAN, engine="openpyxl", datetime_format="yyyy-mm-dd") as xl:
        for name, df in tables.items():
            df.to_excel(xl, sheet_name=name, index=False)
    print(f"Saved {CLEAN.relative_to(ROOT)}")
    for name, df in tables.items():
        print(f"  {name:<13} {len(df):>6} rows")
