#!/usr/bin/env bash
set -euo pipefail

usage() {
  echo "Usage:"
  echo "  $0 INPUT_SPREADSHEET OUTPUT_DIR [--sheet SHEET_NAME]"
  echo ""
  echo "Examples:"
  echo "  $0 data/banks.csv out/"
  echo "  $0 data/banks.xlsx out/ --sheet Sheet1"
}

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

if [[ $# -lt 2 ]]; then usage; exit 1; fi

INPUT="$1"; shift
OUTDIR="$1"; shift || true

# Forward remaining args (e.g., --sheet SHEET_NAME) to Python
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

python3 "${SCRIPT_DIR}/load_parquet__parse_spreadsheet.py" "$INPUT" "$OUTDIR" "$@"
