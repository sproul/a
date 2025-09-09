#!/usr/bin/env python3
import argparse, os, re, math
import pandas as pd
import duckdb
from datetime import datetime, timedelta

def coerce_str(x):
    if pd.isna(x): return ""
    s = str(x).strip()
    return re.sub(r"[\uFEFF\u200B-\u200D\u2060]", "", s)  # strip BOM/zero-width chars

def excel_serial_to_date(val):
    try:
        n = float(val)
        if math.isnan(n): return None
        return (datetime(1899, 12, 30) + timedelta(days=int(n))).date()  # Excel 1900 bug rule
    except Exception:
        return None

def parse_date_cell(cell):
    if pd.isna(cell) or cell == "": return None
    if isinstance(cell, pd.Timestamp): return cell.date()
    if isinstance(cell, datetime):     return cell.date()
    d = excel_serial_to_date(cell)
    if d: return d
    d2 = pd.to_datetime(str(cell), errors="coerce")
    return None if pd.isna(d2) else d2.date()

def main():
    ap = argparse.ArgumentParser(description="Build company/financial_metrics parquet with DuckDB.")
    ap.add_argument("INPUT_SPREADSHEET", help="CSV or XLSX path")
    ap.add_argument("OUTPUT_DIR", help="Directory to write parquet files")
    ap.add_argument("--sheet", help="Sheet name for XLSX", default=None)
    args = ap.parse_args()

    in_path, out_dir, sheet = args.INPUT_SPREADSHEET, args.OUTPUT_DIR, args.sheet
    os.makedirs(out_dir, exist_ok=True)
    comp_parquet = os.path.join(out_dir, "company.parquet")
    fm_parquet   = os.path.join(out_dir, "financial_metrics.parquet")

    ext = os.path.splitext(in_path)[1].lower()
    if ext == ".csv":
        df = pd.read_csv(in_path, header=None, dtype=object, keep_default_na=False)
    elif ext in (".xlsx", ".xls"):
        df = pd.read_excel(in_path, sheet_name=sheet, header=None, dtype=object, engine="openpyxl")
    else:
        raise SystemExit(f"Unsupported extension: {ext}")

    raw = df.copy()                 # keep raw for date parsing
    df = df.applymap(coerce_str)    # normalize strings

    # --- NEW: ignore row 6 (1-based), if present and not the metric header row ---
    if df.shape[0] >= 6:
        row6_first = df.iat[5, 0].lower() if df.shape[1] > 0 else ""
        if row6_first != "field":
            # blank it out so it won't interfere with detection
            df.iloc[5, :] = ""
            raw.iloc[5, :] = ""

    # Locate metric header row "Field, QA Field ID, Field Type"
    metrics_header_row = None
    for r in range(min(40, len(df))):
        c0 = df.iat[r, 0].lower() if df.shape[1] > 0 else ""
        c1 = df.iat[r, 1].lower() if df.shape[1] > 1 else ""
        c2 = df.iat[r, 2].lower() if df.shape[1] > 2 else ""
        if c0 == "field" and c1 in ("qa field id", "qa fieldid", "qa_field_id") and c2 == "field type":
            metrics_header_row = r
            break
    if metrics_header_row is None:
        raise SystemExit("Could not find 'Field, QA Field ID, Field Type' header row.")

    # Helper to find header rows prior to metric header
    def find_row(label):
        lbl = label.lower()
        for r in range(metrics_header_row):
            for c in (2, 1, 0):
                if c < df.shape[1] and df.iat[r, c].strip().lower() == lbl:
                    return r
        return None

    rssd_row   = find_row("rssd id")
    name_row   = find_row("name")
    type_row   = find_row("type")
    period_row = find_row("period")
    duration_row = find_row("duration")  # now expected at (1-based) row 5

    if None in (rssd_row, name_row, type_row, period_row):
        raise SystemExit("Missing one of: RSSD ID, Name, Type, Period header rows.")
    # Duration is required by your new spec; if absent, we’ll still default to MRQ below.

    # Build per-column metadata starting from column 3 (0-based)
    first_data_col = 3
    header_by_col = {}
    for j in range(first_data_col, df.shape[1]):
        rssd_s = df.iat[rssd_row, j] if j < df.shape[1] else ""
        name_s = df.iat[name_row, j] if j < df.shape[1] else ""
        type_s = df.iat[type_row, j] if j < df.shape[1] else ""

        period_cell = raw.iat[period_row, j] if j < raw.shape[1] else None
        period_d = parse_date_cell(period_cell)

        # NEW: duration pulled from new row 5; default to 'MRQ' if blank/missing
        dur_s = "MRQ"
        if duration_row is not None and j < df.shape[1]:
            ds = df.iat[duration_row, j]
            if ds and ds.lower() != "duration":
                dur_s = ds

        if rssd_s == "" and name_s == "":
            continue

        rssd_int = None
        if rssd_s.strip() != "":
            try:
                rssd_int = int(float(rssd_s.strip()))
            except Exception:
                pass

        header_by_col[j] = dict(
            rssd_id=rssd_int,
            rssd_raw=rssd_s.strip(),
            company_name=name_s,
            type=type_s,
            period_date=period_d,
            duration=dur_s
        )

    # Rows after metric header are data
    data_start = metrics_header_row + 1

    companies = {}
    fm_rows = []

    for i in range(data_start, df.shape[0]):
        # skip obviously blank lines
        if all((df.iat[i, c] == "" for c in range(min(6, df.shape[1])))):
            continue

        field_name  = df.iat[i, 0]
        qa_field_id = df.iat[i, 1]
        field_type  = df.iat[i, 2]

        # skip stray header echoes
        if field_name.lower() == "field" and qa_field_id.lower().startswith("qa"):
            continue

        for j, meta in header_by_col.items():
            v = df.iat[i, j] if j < df.shape[1] else ""
            if v == "":
                continue
            rssd_id = meta["rssd_id"]
            if rssd_id is None:
                continue

            if rssd_id not in companies:
                companies[rssd_id] = dict(
                    company_name=meta["company_name"],
                    type=meta["type"],
                    rssd_id=rssd_id,
                    city="",
                    state=""
                )

            fm_rows.append(dict(
                rssd_id=rssd_id,
                company_name=meta["company_name"],
                type=meta["type"],
                property_name=field_name,
                qa_field_id=str(qa_field_id),
                field_type=field_type,
                period_date=meta["period_date"],
                duration=meta["duration"],
                value=str(v)
            ))

    company_df = pd.DataFrame(list(companies.values()),
                              columns=["company_name", "type", "rssd_id", "city", "state"]).drop_duplicates(subset=["rssd_id"])
    fm_df = pd.DataFrame(fm_rows,
                         columns=["rssd_id", "company_name", "type", "property_name", "qa_field_id",
                                  "field_type", "period_date", "duration", "value"])

    con = duckdb.connect()
    con.execute("""
        CREATE TABLE company (
          company_name TEXT,
          type         TEXT,
          rssd_id      BIGINT,
          city         TEXT,
          state        TEXT
        );
    """)
    con.execute("""
        CREATE TABLE financial_metrics (
          rssd_id       BIGINT,
          company_name  TEXT,
          type          TEXT,
          property_name TEXT,
          qa_field_id   TEXT,
          field_type    TEXT,
          period_date   DATE,
          duration      TEXT,
          value         TEXT
        );
    """)
    con.register("company_df", company_df)
    con.register("fm_df", fm_df)
    con.execute("INSERT INTO company SELECT * FROM company_df;")
    con.execute("INSERT INTO financial_metrics SELECT * FROM fm_df;")
    con.execute(f"COPY company TO '{comp_parquet}' (FORMAT PARQUET);")
    con.execute(f"COPY financial_metrics TO '{fm_parquet}' (FORMAT PARQUET);")
    con.close()

    print(f"Wrote:\n  {comp_parquet}\n  {fm_parquet}")

if __name__ == "__main__":
    main()
