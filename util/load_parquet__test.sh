#!/bin/bash
set -o pipefail
if $dp/git/a/util/load_parquet.sh -x $dp/git/a/util/spreadsheets/test_minimal.csv $dp/git/a/data; then
	echo "OK $dp/git/a/util/load_parquet.sh -x $dp/git/a/util/spreadsheets/test_minimal.csv $dp/git/a/data" 1>&2
else
	echo "FAIL $dp/git/a/util/load_parquet.sh -x $dp/git/a/util/spreadsheets/test_minimal.csv $dp/git/a/data" 1>&2
        exit 1
fi

exit
$dp/git/a/util/load_parquet__test.sh -x 