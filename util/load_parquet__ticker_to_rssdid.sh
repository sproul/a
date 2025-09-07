#!/usr/bin/env bash
script_dir=$(dirname $BASH_SOURCE|sed -e 's;^/$;;')      # if the containing dir is /, scripting goes better if script_dir is ''
cd $script_dir
set -Eeuo pipefail

# Load ticker→RSSD mapping CSV into Parquet with upsert-by-ticker.
# Output: OUTDIR/ticker_to_rssd.parquet
#
# CSV must contain 2 columns: ticker, RSSD ID (case/spacing-insensitive).
# Examples of accepted headers: "ticker", "Ticker", "symbol"; "RSSD ID", "rssd_id", "RSSDID".
#
# Options and behavior mirror your other loader:
#  - --json         : emit one-line JSON summary to stdout
#  - --lock-wait N  : wait up to N seconds for an OUTDIR lock
#  - --python / --duckdb : override binaries
#
# Exit codes: 0 ok, 64 usage, 66 missing input, 65 parse error, 73 lock timeout

usage() {
  cat >&2 <<'USAGE'
Usage:
  load_ticker_map.sh INPUT_CSV OUTPUT_DIR [--json] [--lock-wait SECONDS] [--python PY] [--duckdb DUCKDB]
USAGE
}

INPUT=""
OUTDIR=""
JSON_SUMMARY=0
LOCK_WAIT=0
PY="${PYTHON_BIN:-python3}"
DUCKDB_BIN="${DUCKDB_BIN:-duckdb}"

while [[ $# -gt 0 ]]; do
  case "${1:-}" in
    -h|--help) usage; exit 64;;
    --json) JSON_SUMMARY=1; shift;;
    --lock-wait) [[ $# -ge 2 ]] || { echo "Missing value for --lock-wait" >&2; exit 64; }
                 LOCK_WAIT="$2"; shift 2;;
    --python) [[ $# -ge 2 ]] || { echo "Missing value for --python" >&2; exit 64; }
              PY="$2"; shift 2;;
    --duckdb) [[ $# -ge 2 ]] || { echo "Missing value for --duckdb" >&2; exit 64; }
              DUCKDB_BIN="$2"; shift 2;;
    -*)
      echo "Unknown option: $1" >&2; usage; exit 64;;
    *)
      if [[ -z "$INPUT" ]]; then INPUT="$1"
      elif [[ -z "$OUTDIR" ]]; then OUTDIR="$1"
      else echo "Unexpected extra arg: $1" >&2; usage; exit 64; fi
      shift;;
  esac
done

[[ -n "$INPUT" && -n "$OUTDIR" ]] || { usage; exit 64; }
[[ -f "$INPUT" ]] || { echo "Input not found: $INPUT" >&2; exit 66; }

mkdir -p "$OUTDIR"
TMPDIR="$(mktemp -d)"
cleanup() { rm -rf "$TMPDIR"; [[ -n "${LOCKDIR:-}" ]] && rmdir "$LOCKDIR" >/dev/null 2>&1 || true; }
trap cleanup EXIT

# Lock (optional)
LOCKDIR="$OUTDIR/.ticker_map.lock"
if [[ "$LOCK_WAIT" -le 0 ]]; then
  if ! mkdir "$LOCKDIR" 2>/dev/null; then
    echo "Lock busy: $LOCKDIR (use --lock-wait SECONDS)" >&2; exit 73
  fi
else
  deadline=$(( $(date +%s) + LOCK_WAIT ))
  until mkdir "$LOCKDIR" 2>/dev/null; do
    (( $(date +%s) >= deadline )) && { echo "Lock timeout after ${LOCK_WAIT}s: $LOCKDIR" >&2; exit 73; }
    sleep 1
  done
fi

MAP_NEW="$TMPDIR/ticker_to_rssd_new.parquet"
MAP_OUT="$OUTDIR/ticker_to_rssd.parquet"
MAP_BEFORE="$TMPDIR/ticker_to_rssd_before.parquet"
[[ -f "$MAP_OUT" ]] && cp -f "$MAP_OUT" "$MAP_BEFORE" || true

# Parse & normalize
set +e
"$PY" "$(dirname "$0")/load_parquet__parse_ticker_to_rssdid.py" "$INPUT" "$MAP_NEW"
st=$?
set -e
if [[ $st -ne 0 ]]; then
  echo "Parser failed with exit $st" >&2
  exit 65
fi

# Upsert by ticker (prefer new)
MAP_MERGED="$TMPDIR/ticker_to_rssd_merged.parquet"
if [[ ! -f "$MAP_OUT" ]]; then
  cp -f "$MAP_NEW" "$MAP_MERGED"
else
  "$DUCKDB_BIN" -c "
    PRAGMA threads=4;
    CREATE TEMP TABLE old AS SELECT * FROM read_parquet('$MAP_OUT');
    CREATE TEMP TABLE new AS SELECT * FROM read_parquet('$MAP_NEW');

    CREATE TEMP TABLE combined AS
      SELECT 'old' AS src, * FROM old
      UNION ALL
      SELECT 'new' AS src, * FROM new;

    CREATE TEMP TABLE ranked AS
      SELECT *,
             ROW_NUMBER() OVER (
               PARTITION BY ticker
               ORDER BY CASE WHEN src='new' THEN 0 ELSE 1 END
             ) AS rn
      FROM combined;

    CREATE TEMP TABLE merged AS
      SELECT * EXCLUDE (src, rn)
      FROM ranked
      WHERE rn = 1;

    COPY (SELECT * FROM merged)
      TO '$MAP_MERGED' (FORMAT PARQUET, COMPRESSION ZSTD);
  " >/dev/null
fi
mv -f "$MAP_MERGED" "$MAP_OUT"

# Stats for JSON
j() { tr -d '\r' | tail -n +2 | tr -d '[:space:]'; }

total_rows=$("$DUCKDB_BIN" -csv -c "SELECT COUNT(*) FROM read_parquet('$MAP_OUT');" | j)
new_rows=$("$DUCKDB_BIN" -csv -c "SELECT COUNT(*) FROM read_parquet('$MAP_NEW');" | j)
if [[ -f "$MAP_BEFORE" ]]; then
  overlaps=$("$DUCKDB_BIN" -csv -c "
    SELECT COUNT(*) FROM (
      SELECT o.ticker FROM read_parquet('$MAP_BEFORE') o
      JOIN read_parquet('$MAP_NEW') n USING (ticker)
    );" | j)
else
  overlaps="0"
fi
inserts=$(( ${new_rows:-0} - ${overlaps:-0} ))
updates=$(( ${overlaps:-0} ))

if [[ $JSON_SUMMARY -eq 1 ]]; then
  printf '{'
  printf '"input":"%s",' "$(basename "$INPUT")" | sed 's/"/\\"/g'
  printf '"ticker_to_rssd":{"total":%s,"upserted_in_this_run":%s,"inserted":%s,"updated":%s},' \
    "${total_rows:-0}" "${new_rows:-0}" "${inserts:-0}" "${updates:-0}"
  printf '"output":"%s"' "$MAP_OUT"
  printf '}\n'
else
  echo "OK  → $MAP_OUT  (total: ${total_rows:-0}, inserted: ${inserts:-0}, updated: ${updates:-0})"
fi
exit
cd $dp/git/a/util/
bash -x $dp/git/a/util/load_parquet__ticker_to_rssdid.sh spreadsheets/ticker_to_rssdid.csv ../data
