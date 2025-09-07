#!/bin/bash
script_dir=$(dirname $BASH_SOURCE|sed -e 's;^/$;;')      # if the containing dir is /, scripting goes better if script_dir is ''
set -o pipefail
debug_mode=''
dry_mode=''
schema_mode=''
t=`mktemp`; trap "rm $t*" EXIT
verbose_mode=''
while [ -n "$1" ]; do
        case "$1" in
                -all)
                        cd $script_dir/../data
                        find . -type f | grep '\.parquet$' > $t.0
                        while read parquet_fn; do
                                echo "$0 $debug_mode $schema_mode $parquet_fn"
                                $0       $debug_mode $schema_mode $parquet_fn
                                echo =======================================================================
                        done < $t.0
                        ls -l *.csv
                        exit
                ;;
                -dry)
                        dry_mode=-dry
                ;;
                -q|-quiet)
                        verbose_mode=''
                ;;
                -schema)
                        schema_mode=-schemea
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
parquet_fn=$1
if [ -n "$schema_mode" ]; then
        echo "duckdb -c \"DESCRIBE SELECT * FROM read_parquet('$parquet_fn', hive_partitioning=1);\""
        duckdb       -c "DESCRIBE SELECT * FROM read_parquet('$parquet_fn', hive_partitioning=1);"
else
        csv_fn=`sed -e 's/parquet$/csv/' <<< $parquet_fn`
        if [ "$csv_fn" = "$parquet_fn" ]; then
                echo "FAIL unable to derive distinct csv_fn from $parquet_fn" 1>&2
                exit 1
        fi
        duckdb -c "COPY (SELECT * FROM read_parquet('$parquet_fn'))
                TO '$csv_fn' (FORMAT CSV, HEADER, DELIMITER ',');"
        ls -l $csv_fn
fi
exit
$dp/git/a/util/parquet_duckdb_dump.sh -x -all