#!/usr/bin/env python3
import argparse
import pandas as pd

# Reads a CSV with columns: ticker, RSSD ID (case/spacing-insensitive).
# Normalizes:
#   - ticker: uppercased, trimmed
#   - RSSD ID: BIGINT (nullable Int64)
# Drops rows missing either, dedupes by ticker (latest row wins).

CANON_TICKER_COL = "ticker"
CANON_RSSD_COL = "RSSD ID"

def find_column(df: pd.DataFrame, candidates: list[str]) -> str | None:
    # match ignoring case and punctuation/whitespace
    norm = {c: "".join(ch.lower() for ch in str(c) if ch.isalnum()) for c in df.columns}
    wanted = {"".join(ch.lower() for ch in s if ch.isalnum()): s for s in candidates}
    for col, key in norm.items():
        if key in wanted:
            return col
    return None

def main():
    ap = argparse.ArgumentParser(description="Parse ticker→RSSD CSV into Parquet")
    ap.add_argument("input_csv")
    ap.add_argument("output_parquet")
    args = ap.parse_args()

    df = pd.read_csv(args.input_csv, dtype=object)  # preserve as strings, we'll coerce
    if df.shape[1] < 2:
        raise SystemExit("Expected at least 2 columns (ticker, RSSD ID)")

    ticker_col = find_column(df, ["ticker", "symbol"])
    rssd_col   = find_column(df, ["rssdid", "rssd id", "rssd_id", "rssd"])
    if ticker_col is None or rssd_col is None:
        raise SystemExit(f"Could not find 'ticker' and 'RSSD ID' columns in {list(df.columns)}")

    # Select & rename
    out = df[[ticker_col, rssd_col]].copy()
    out.columns = [CANON_TICKER_COL, CANON_RSSD_COL]

    # Clean
    out[CANON_TICKER_COL] = out[CANON_TICKER_COL].astype(str).str.strip().str.upper()
    out[CANON_RSSD_COL] = pd.to_numeric(out[CANON_RSSD_COL], errors="coerce").astype("Int64")

    # Drop empties
    out = out[
        out[CANON_TICKER_COL].notna() & (out[CANON_TICKER_COL] != "") &
        out[CANON_RSSD_COL].notna()
    ].reset_index(drop=True)

    # Deduplicate by ticker: keep last occurrence
    out = out.drop_duplicates(subset=[CANON_TICKER_COL], keep="last").reset_index(drop=True)

    # Write
    out.to_parquet(args.output_parquet, index=False)

if __name__ == "__main__":
    main()
