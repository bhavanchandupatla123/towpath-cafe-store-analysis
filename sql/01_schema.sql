-- The Towpath: star schema
-- Fact tables: Sales, Shifts, Wastage, Purchases.  Dimensions: Products, Staff, Suppliers, Date.
-- Written for SQLite (what python/03_run_sql.py uses). The same design works in SQL Server or PostgreSQL.

CREATE TABLE Date (
    Date         TEXT PRIMARY KEY,      -- yyyy-mm-dd, one row per day, 2024-01-01 to 2025-12-31
    Year         INTEGER, Quarter TEXT, MonthNo INTEGER, Month TEXT, YearMonth TEXT,
    WeekStart    TEXT, DayNo INTEGER, Day TEXT, Season TEXT, IsWeekend TEXT, SeasonNo INTEGER,
    avg_temp_c   REAL, rainfall_mm REAL, Weather TEXT, WeatherNo INTEGER
);

CREATE TABLE Suppliers (
    supplier_id   TEXT PRIMARY KEY,
    supplier_name TEXT, delivery_cost REAL, delivery_days TEXT
);

CREATE TABLE Products (
    product_id    TEXT PRIMARY KEY,
    product_name  TEXT, category TEXT, business_area TEXT,   -- 'Café' or 'Store'
    cost_price    REAL, selling_price REAL,                  -- current (Dec 2025) price list
    supplier_id   TEXT REFERENCES Suppliers(supplier_id)
);

CREATE TABLE Staff (
    staff_id      TEXT PRIMARY KEY,
    name TEXT, role TEXT, hourly_rate REAL, business_area TEXT
);

CREATE TABLE Sales (                                          -- one row per product line on a till receipt
    sales_line_id  INTEGER PRIMARY KEY,
    transaction_id TEXT,                                      -- one receipt = one customer visit
    date           TEXT REFERENCES Date(Date),
    time TEXT, hour INTEGER,
    product_id     TEXT REFERENCES Products(product_id),
    quantity       INTEGER, unit_price REAL,
    payment_method TEXT,
    staff_id       TEXT REFERENCES Staff(staff_id),
    line_type      TEXT,                                      -- Sale / Refund / Zero / Suspicious
    unit_cost      REAL                                       -- cost paid at that week's delivery
);

CREATE TABLE Shifts (
    shift_id TEXT PRIMARY KEY,
    staff_id TEXT REFERENCES Staff(staff_id),
    date     TEXT REFERENCES Date(Date),
    start_time TEXT, end_time TEXT, hours REAL
);

CREATE TABLE Wastage (
    waste_id   TEXT PRIMARY KEY,
    date       TEXT REFERENCES Date(Date),
    product_id TEXT REFERENCES Products(product_id),
    quantity_wasted INTEGER, reason TEXT
);

CREATE TABLE Purchases (
    purchase_id   TEXT PRIMARY KEY,
    delivery_week TEXT,                                       -- Monday of the delivery week
    supplier_id   TEXT REFERENCES Suppliers(supplier_id),
    product_id    TEXT REFERENCES Products(product_id),
    quantity INTEGER, unit_cost REAL
);
