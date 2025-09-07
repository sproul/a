#!/bin/bash
set -o pipefail
duckdb mydb.duckdb
exit
cat <<EOF | $dp/git/a/util/parquet_duckdb_sql.sh
select value from read_parquet('../data/financial_metrics.parquet', hive_partitioning=1)
EOF
