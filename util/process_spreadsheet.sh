#!/bin/bash
script_dir=$(dirname $BASH_SOURCE|sed -e 's;^/$;;')	 # if the containing dir is /, scripting goes better if script_dir is ''
export PATH=$script_dir:$script_dir/../static_analysis:$PATH


Extract_rssd_ids()
{
	head -1 $csv_fn |sed -e 's/,,RSSD ID,//' -e 's/[^-0-9,]//g' | tr -d '\r' | tr ',' '\n' | sort -u
}

New_data_seen()
{
	out_fn=$1
	dir=`dirname $out_fn`
	penultimate_latest_fn=`ls $dir/*.csv | tail -2 | head -1`
	if [ ! -f "$penultimate_latest_fn" ]; then
		echo "OK $out_fn is the first file here, so it is new data" 1>&2
		return 0
	fi
	if diff $penultimate_latest_fn $out_fn > /dev/null 2>&1; then
		echo "OK no new data seen in $out_fn vs $penultimate_latest_fn" 1>&2
		if mv $out_fn /tmp; then
			echo "OK mv $out_fn /tmp" 1>&2
		else
			echo "FAIL mv $out_fn /tmp" 1>&2
			exit 1
		fi
		return 1
	fi
	echo "OK new data seen in $out_fn not seen in $penultimate_latest_fn" 1>&2
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
spreadsheet_fn="$1"
if [ ! -f "$spreadsheet_fn" ]; then
	echo "FAIL: expected file at \"$spreadsheet_fn\"" 1>&2
	exit 1
fi
case "$spreadsheet_fn" in
	*.csv)
		csv_fn="$spreadsheet_fn.clean"
		rm -f $csv_fn
		if csv.rm_embedded_commas_and_number_quotes.sh -suffix clean $spreadsheet_fn; then
			echo "OK csv.rm_embedded_commas_and_number_quotes.sh -suffix clean $spreadsheet_fn" 1>&2
		else
			echo "FAIL csv.rm_embedded_commas_and_number_quotes.sh -suffix clean $spreadsheet_fn" 1>&2
                        exit 1
                fi
		if [ ! -f "$csv_fn" ]; then
			echo "FAIL: expected file at \"$csv_fn\"" 1>&2
			exit 1
		else
			echo "OK $spreadsheet_fn cleaned into $csv_fn" 1>&2
		fi
	;;
	*)
		echo "FAIL require csv format for now, but saw \"$spreadsheet_fn\"" 1>&2
		exit 1
	;;
esac
updated_ticker_rssd_id_pairs_fn=$script_dir/../public/updated_ticker_rssd_id_pairs.csv
if [ -f $updated_ticker_rssd_id_pairs_fn ]; then
	if age_in_days.gt 1 $updated_ticker_rssd_id_pairs_fn; then
		if rm -f $updated_ticker_rssd_id_pairs_fn; then
			echo "OK rm -f $updated_ticker_rssd_id_pairs_fn" 1>&2
		else
			echo "FAIL rm -f $updated_ticker_rssd_id_pairs_fn" 1>&2
			exit 1
		fi
	fi
fi
Extract_rssd_ids > $t.0
while read rssd_id; do
	echo "OK rssd_id=$rssd_id" 1>&2
	out_fn=$script_dir/../public/firms_by_rssd_id/$rssd_id/`date '+%Y-%m-%d'`.csv
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
		if ! grep $rssd_id $script_dir/../data/updated_rssd_ids; then
			echo $rssd_id >> $script_dir/../data/updated_rssd_ids
		fi
		if load_parquet.sh $debug_mode $out_fn $script_dir/../data; then
			echo "OK load_parquet.sh $debug_mode $out_fn $script_dir/../data" 1>&2
		else
			echo "FAIL load_parquet.sh $debug_mode $out_fn $script_dir/../data" 1>&2
			exit 1
		fi
		report_fn=$dp/git/a/public/firms_by_rssd_id/$rssd_id/report.htm
		rm -f $report_fn
		if financial_analyzer.sh -x $rssd_id > $t.out 2>&1; then
			echo "OK financial_analyzer.sh $rssd_id" 1>&2
			if [ -n "$debug_mode" ]; then
				echo "financial_analyzer.sh output:"
				cat $t.out
				echo "EOF"
			fi 1>&2
			if [ ! -f "$report_fn" ]; then
				echo "FAIL: process_spreadsheet.sh expected generated report at \"$report_fn\"" 1>&2
				exit 1
			else
				echo "OK: process_spreadsheet.sh saw generated report at \"$report_fn\"" 1>&2
				ticker=`rssd_ids.sh -from_rssd_id $rssd_id`
				if ! grep "$ticker,$rssd_id" $updated_ticker_rssd_id_pairs_fn; then
					echo "$ticker,$rssd_id" >> $updated_ticker_rssd_id_pairs_fn
				fi
			fi
		else
			echo "FAIL financial_analyzer.sh $rssd_id" 1>&2
			cat $t.out 1>&2
			exit 1
		fi
	fi
done

exit
spreadsheet_fn=$dp/git/a/util/spreadsheets/fsb_generated_all_non_test5.csv
csv_fn=$dp/git/a/util/spreadsheets/fsb_generated_all_non_test5.csv.clean
$dp/git/a/util/process_spreadsheet.sh -x $spreadsheet_fn
