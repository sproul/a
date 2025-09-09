#!/bin/bash
script_dir=$(dirname $BASH_SOURCE|sed -e 's;^/$;;')	 # if the containing dir is /, scripting goes better if script_dir is ''
export PATH=$script_dir:$PATH

Extract_rssd_ids()
{
	head -1 $csv_fn |sed -e 's/,,RSSD ID,//' -e 's/[^-0-9,]//g' | tr -d '\r' | tr ',' '\n' | sort -u
}

New_data_seen()
{
	out_fn=$1
	dir=`dirname $out_fn`
	ls $dir/*.csv | tail -2 | tr '\n' ' ' > $t.latest_2
	if diff `cat $t.latest_2` > /dev/null 2>&1; then
		echo "OK no new data seen in $out_fn" 1>&2
		return 1
	fi
	echo "OK new data seen in $out_fn" 1>&2
	return 0
}

set -o pipefail
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
csv_fn=$1

Extract_rssd_ids > $t.0
while read rssd_id; do
	echo "OK rssd_id=$rssd_id" 1>&2
	out_fn=$script_dir/../data/firms_by_rssd_id/$rssd_id/`date '+%Y-%m-%d'`.csv
	dir=`dirname $out_fn`
	if mkdir -p $dir; then
		echo "OK mkdir -p $dir" 1>&2
	else
		echo "FAIL mkdir -p $dir" 1>&2
		exit 1
	fi
	csv.extract_QA_spreadsheet_data_for_rssd_id.sh $rssd_id $csv_fn > $out_fn
	if [ -n "$debug_mode" ]; then
		echo "diff $csv_fn $out_fn"
		diff	   $csv_fn $out_fn
	fi
	if New_data_seen $out_fn; then
		echo $rssd_id >> $dp/git/a/data/updated_rssd_ids
                if load_parquet.sh $debug_mode $out_fn $script_dir/../data; then
			echo "OK load_parquet.sh $debug_mode $out_fn $script_dir/../data" 1>&2
		else
			echo "FAIL load_parquet.sh $debug_mode $out_fn $script_dir/../data" 1>&2
                        exit 1
                fi
	fi
done < $t.0

exit
$dp/git/a/util/csv.divide_QA_spreadsheet_by_firm.sh -x $dp/git/a/util/spreadsheets/test_minimal.csv