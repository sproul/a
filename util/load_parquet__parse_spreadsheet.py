#!/usr/bin/env python3
import argparse, math
from datetime import datetime, timedelta
import numpy as np
import pandas as pd

# Columns (0-based):
# 0: Company Name, 1: Type, 2: RSSD ID, 3: City, 4: State
# 5-6 ignored
# 7..N financial metrics with 5 header rows:
#   hdr1: property_name
#   hdr2: qa_field_id
#   hdr3: field_type
#   hdr4: period (OLE Automation Date)
#   hdr5: duration (MRQ/LTM/"")

def ole_to_datetime(x):
    if pd.isna(x):
        return pd.NaT
    try:
        v = float(x)
    except Exception:
        return pd.NaT
    if not math.isfinite(v):
        return pd.NaT
    # OLE Automation epoch: 1899-12-30
    return datetime(1899, 12, 30) + timedelta(days=v)

def read_raw(path: str, sheet: str | None) -> pd.DataFrame:
    if path.lower().endswith(".csv"):
        return pd.read_csv(path, header=None, dtype=object)
    kw = dict(header=None, dtype=object, engine="openpyxl")
    if sheet:
        kw["sheet_name"] = sheet
    return pd.read_excel(path, **kw)

def main():
    ap = argparse.ArgumentParser(description="Parse spreadsheet to Parquet (company + financial_metrics)")
    ap.add_argument("input_path")
    ap.add_argument("company_out_parquet")
    ap.add_argument("financial_out_parquet")
    ap.add_argument("--sheet", help="Excel sheet name (optional)")
    args = ap.parse_args()

    raw = read_raw(args.input_path, args.sheet)
    if raw.shape[0] < 6:
        raise SystemExit("Expected at least 6 rows (5 header rows + data)")

    hdr1 = raw.iloc[0].fillna("").astype(str)  # property_name
    hdr2 = raw.iloc[1].fillna("").astype(str)  # qa_field_id
    hdr3 = raw.iloc[2].fillna("").astype(str)  # field_type
    hdr4 = raw.iloc[3]                          # period (OLE date)
    hdr5 = raw.iloc[4].fillna("").astype(str)  # duration
    data = raw.iloc[5:].reset_index(drop=True)

    # ---- Company table (columns 0..4) ----
    company_cols = [0,1,2,3,4]
    company_names = ["Company Name", "Type", "RSSD ID", "City", "State"]
    company_df = data.iloc[:, company_cols].copy()
    company_df.columns = company_names

    # RSSD ID to nullable Int64
    company_df["RSSD ID"] = pd.to_numeric(company_df["RSSD ID"], errors="coerce").astype("Int64")
    company_df = company_df[~company_df["RSSD ID"].isna()].reset_index(drop=True)

    # ---- Financial metrics (columns 7..N, ignoring 5-6) ----
    start_fm = 7
    if data.shape[1] <= start_fm:
        fm_long = pd.DataFrame(columns=[
            "RSSD ID", "Company Name", "Type",
            "property_name", "qa_field_id", "field_type",
            "period_date", "duration", "value"
        ])
    else:
        fm_cols = list(range(start_fm, data.shape[1]))
        prop_names = [hdr1[i] if i < len(hdr1) else "" for i in fm_cols]
        qa_ids     = [hdr2[i] if i < len(hdr2) else "" for i in fm_cols]
        ftypes     = [hdr3[i] if i < len(hdr3) else "" for i in fm_cols]
        periods    = [hdr4[i] if i < len(hdr4) else np.nan for i in fm_cols]
        durations  = [hdr5[i] if i < len(hdr5) else "" for i in fm_cols]

        V = data.iloc[:, fm_cols].copy()
        V.columns = pd.RangeIndex(len(fm_cols))  # 0..k-1 temp labels

        ident = pd.DataFrame({
            "Company Name": data.iloc[:, 0].values,
            "Type":         data.iloc[:, 1].values,
            "RSSD ID":      pd.to_numeric(data.iloc[:, 2], errors="coerce").astype("Int64")
        })

        long = V.melt(ignore_index=False, var_name="_colidx", value_name="value").reset_index(drop=True)
        meta = pd.DataFrame({
            "_colidx": list(range(len(fm_cols))),
            "property_name": prop_names,
            "qa_field_id": qa_ids,
            "field_type": ftypes,
            "period_oad": periods,
            "duration": durations
        })
        long = long.merge(meta, on="_colidx", how="left").drop(columns=["_colidx"])

        n_rows = data.shape[0]
        rep = np.repeat(np.arange(n_rows), len(fm_cols))
        ident_rep = pd.DataFrame({
            "Company Name": ident["Company Name"].values[rep],
            "Type":         ident["Type"].values[rep],
            "RSSD ID":      ident["RSSD ID"].values[rep],
        })

        fm_long = pd.concat([ident_rep, long], axis=1)

        # Convert OLE to datetime (keep DATE semantics on write/merge)
        fm_long["period_date"] = pd.to_datetime(fm_long["period_oad"].map(ole_to_datetime))
        fm_long = fm_long.drop(columns=["period_oad"])

        # Drop rows with no RSSD ID
        fm_long = fm_long[~fm_long["RSSD ID"].isna()].reset_index(drop=True)

        # Filter out wholly blank records (no value + no qa_field_id)
        def is_blank(x):
            return (pd.isna(x)) or (isinstance(x, str) and x.strip() == "")
        keep = ~(fm_long["value"].apply(is_blank) & fm_long["qa_field_id"].apply(is_blank))
        fm_long = fm_long[keep].reset_index(drop=True)

    # Best-effort numeric coercion of value (strings preserved when non-numeric)
    fm_long["value"] = pd.to_numeric(fm_long["value"], errors="ignore")

    # Write outputs
    company_df.to_parquet(args.company_out_parquet, index=False)
    fm_long.to_parquet(args.financial_out_parquet, index=False)

if __name__ == "__main__":
    main()
