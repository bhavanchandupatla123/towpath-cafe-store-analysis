"""
03_run_sql.py
-------------
Loads the clean workbook into a SQLite database, runs every query in the sql/
folder and writes the answers to outputs/sql_results.md.

This proves the SQL actually runs and returns the same numbers as the Python
notebook and the Power BI dashboard.

Run:  python python/03_run_sql.py
"""
from pathlib import Path
import re
import sqlite3

import pandas as pd

ROOT = Path(__file__).resolve().parents[1]
CLEAN = ROOT / "data" / "clean" / "towpath_powerbi_data.xlsx"
OUT = ROOT / "outputs" / "sql_results.md"

con = sqlite3.connect(":memory:")
con.executescript((ROOT / "sql" / "01_schema.sql").read_text(encoding="utf-8"))

tables = pd.read_excel(CLEAN, sheet_name=None)
for name in ["Date", "Suppliers", "Products", "Staff", "Sales", "Shifts", "Wastage", "Purchases"]:
    df = tables[name].copy()
    for col in df.select_dtypes("datetime").columns:        # SQLite stores dates as yyyy-mm-dd text
        df[col] = df[col].dt.strftime("%Y-%m-%d")
    df.to_sql(name, con, if_exists="append", index=False)

lines = ["# SQL results", "",
         "Produced by `python/03_run_sql.py` (SQLite). Do not edit by hand: re-run the script instead.", ""]
for file in ["02_data_quality_checks.sql", "03_business_questions.sql"]:
    lines += [f"## {file}", ""]
    text = (ROOT / "sql" / file).read_text(encoding="utf-8")
    # each query starts with a "-- Qn: title" comment and ends with a semicolon
    for title, query in re.findall(r"^-- (Q\d+: [^\n]*)\n(.*?;)", text, flags=re.S | re.M):
        result = pd.read_sql_query(query, con)
        for col in result.columns:                           # tidy display: years and counts as whole numbers
            if col == "Year":
                result[col] = result[col].astype(str)
            elif result[col].dtype == float and (result[col].dropna() % 1 == 0).all() and not col.endswith("pct"):
                result[col] = result[col].astype("Int64")
        lines += [f"**{title}**", "", result.to_markdown(index=False, floatfmt=",.2f"), ""]
        print(f"ok  {file}  {title}  ({len(result)} rows)")

OUT.write_text("\n".join(lines), encoding="utf-8")
print(f"Saved {OUT.relative_to(ROOT)}")
