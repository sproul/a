#!/usr/bin/env bash
set -euo pipefail

# Usage:
#   ./load_parquet.sh INPUT_SPREADSHEET OUTPUT_DIR [--sheet SHEET_NAME]
# Notes:
#   - Columns:
#       1 Company Name, 2 Type, 3 RSSD ID (unique int), 4 City, 5 State
#       6–7 ignored
#       8..N = financial metric columns
#   - Writes/merges into:
#       OUTPUT_DIR/company.parquet
#       OUTPUT_DIR/financial_metrics.parquet
#
# Deps:
#   python3 (pandas, pyarrow, openpyxl) and duckdb CLI

debug_mode=''
dry_mode=''
t=`mktemp`; trap "rm $t*" EXIT
verbose_mode=''
while [ -n "$1" ]; do
        case "$1" in
                -dry)
                        dry_mode=-dry
                ;;
                -q|-quiet)
                        verbose_mode=''
                ;;
                -v|-verbose)
                        verbose_mode=-v
                ;;
                -x)
                        set -x
                        debug_mode=-x
                ;;
                -*)
                        echo "FAIL unrecognized flag $1" 1>&2
                        exit 1
                ;;
                *)
                        break
                ;;
        esac
        shift
done
INPUT="$1"; shift
OUTDIR="$1"; shift
SHEET_ARG=''
if [[ "${1-}" == "--sheet" && -n "${2-}" ]]; then
  SHEET_ARG="--sheet $2"
  shift 2
fi

mkdir -p "$OUTDIR"
TMPDIR="$(mktemp -d)"
trap 'rm -rf "$TMPDIR"' EXIT

COMPANY_NEW="$TMPDIR/company_new.parquet"
FM_NEW="$TMPDIR/financial_metrics_new.parquet"
COMPANY_OUT="$OUTDIR/company.parquet"
FM_OUT="$OUTDIR/financial_metrics.parquet"

# 1) Parse spreadsheet -> temp parquet files
python3 "$(dirname "$0")/load_parquet__parse_spreadsheet.py" "$INPUT" "$COMPANY_NEW" "$FM_NEW" $SHEET_ARG

# 2) Upsert company rows by RSSD ID
if [[ ! -f "$COMPANY_OUT" ]]; then
  cp "$COMPANY_NEW" "$COMPANY_OUT"
else
  duckdb -c "
    PRAGMA threads=auto;
    CREATE TEMP TABLE old AS SELECT * FROM read_parquet('$COMPANY_OUT');
    CREATE TEMP TABLE new AS SELECT * FROM read_parquet('$COMPANY_NEW');

    -- Prefer 'new' on RSSD ID conflicts
    CREATE TEMP TABLE merged AS
      SELECT * FROM old WHERE \"RSSD ID\" NOT IN (SELECT \"RSSD ID\" FROM new)
      UNION ALL
      SELECT * FROM new;

    COPY (SELECT * FROM merged)
      TO '$COMPANY_OUT' (FORMAT PARQUET, COMPRESSION ZSTD);
  "
fi

# 3) Upsert financial metrics by composite key
if [[ ! -f "$FM_OUT" ]]; then
  cp "$FM_NEW" "$FM_OUT"
else
  duckdb -c "
    PRAGMA threads=auto;
    CREATE TEMP TABLE old AS SELECT * FROM read_parquet('$FM_OUT');
    CREATE TEMP TABLE new AS SELECT * FROM read_parquet('$FM_NEW');

    CREATE TEMP TABLE combined AS
      SELECT 'old' AS src, * FROM old
      UNION ALL
      SELECT 'new' AS src, * FROM new;

    -- Deduplicate on (RSSD ID, qa_field_id, field_type, period_date::date, duration)
    CREATE TEMP TABLE ranked AS
      SELECT *,
             ROW_NUMBER() OVER (
               PARTITION BY \"RSSD ID\",
                            COALESCE(qa_field_id,''),
                            COALESCE(field_type,''),
                            CAST(period_date AS DATE),
                            COALESCE(duration,'')
               ORDER BY CASE WHEN src='new' THEN 0 ELSE 1 END
             ) AS rn
      FROM combined;

    CREATE TEMP TABLE merged AS
      SELECT * EXCLUDE (src, rn)
      FROM ranked
      WHERE rn = 1;

    COPY (SELECT * FROM merged)
      TO '$FM_OUT' (FORMAT PARQUET, COMPRESSION ZSTD);
  "
fi

echo "OK Company            → $COMPANY_OUT" 1>&2
echo "OK Financial Metrics  → $FM_OUT" 1>&2

exit
$dp/git/a/util/load_parquet.sh -x $dp/git/a/util/spreadsheets/test_minimal.csv $dp/git/a/data