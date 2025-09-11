#!/bin/bash
script_dir=$(dirname $BASH_SOURCE|sed -e 's;^/$;;')      # if the containing dir is /, scripting goes better if script_dir is ''
export PATH=$script_dir:$script_dir/../util:$PATH
set -o pipefail
debug_mode=''
dry_mode=''
t=`mktemp`; trap "rm $t*" EXIT
verbose_mode=''
. python.inc
while [ -n "$1" ]; do
        case "$1" in
                -all)
                        tr ',' ' ' < $script_dir/../util/spreadsheets/tickers_and_rssd_ids.csv > $t.0
                        while read ticker rssd_id; do
                                case "$ticker" in
                                        TEST*|ticker)
                                                continue
                                        ;;
                                        *)
                                                echo   "$0 $debug_mode --ticker $ticker $rssd_id"
                                                if [ -z "$dry_mode" ]; then
                                                        $0 $debug_mode --ticker $ticker $rssd_id
                                                fi
                                        ;;
                                esac
                        done < $t.0
                        exit 0
                ;;
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
cd $script_dir
input_param=$1
if [ -z "$input_param" ]; then
        echo "FAIL: expected a value for \"rssd_id\" or \"ticker\" but saw nothing" 1>&2
        exit 1
fi

# Check if input is numeric (rssd_id) or alphabetic (ticker)
if [[ "$input_param" =~ ^[0-9]+$ ]]; then
        # Input is numeric, treat as rssd_id
        rssd_id=$input_param
else
        # Input is alphabetic, treat as ticker and derive rssd_id
        rssd_id=$(rssd_ids.sh -from_ticker "$input_param")
        if [ $? -ne 0 ]; then
                echo "FAIL: could not derive rssd_id from ticker \"$input_param\"" 1>&2
                exit 1
        fi
fi

python3 financial_analyzer.py $rssd_id
exit
$dp/git/a/static_analysis/financial_analyzer.sh 118490
exit
$dp/git/a/static_analysis/financial_analyzer.sh -dry -all