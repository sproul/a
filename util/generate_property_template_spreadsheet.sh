#!/bin/bash

Gen_csv()
{
	# field name, leave blank:
	(( i = QAFieldID0 ))
	while [ $i -le $QAFieldIDn ]; do
		printf ","
		(( i++ ))
	done
	echo ''
	# QAFieldID
	(( i = QAFieldID0 ))
	while [ $i -le $QAFieldIDn ]; do
		printf "$i,"
		(( i++ ))
	done
	echo ''
	# firm type (always Bank for now)
	(( i = QAFieldID0 ))
	while [ $i -le $QAFieldIDn ]; do
		printf "Bank,"
		(( i++ ))
	done
	echo ''
	# date
	(( i = QAFieldID0 ))
	while [ $i -le $QAFieldIDn ]; do
		printf "$excel_date_12_31_2024,"
		(( i++ ))
	done
	echo ''
	# time period type
	(( i = QAFieldID0 ))
	while [ $i -le $QAFieldIDn ]; do
		printf "MRQ,"
		(( i++ ))
	done
	echo ''
}

Append_new_fields_to_xlsx()
{
	# Take the csv file and append the new fields to the xlsx file, extending the spreadsheet to the right.
	if [ ! -r "$csv_fn" ]; then
		echo "FAIL: expected readable file at \"$csv_fn\"" 1>&2
		exit 1
	fi
	if [ ! -r "$input_xlsx_fn" ]; then
		echo "FAIL: expected readable file at \"$input_xlsx_fn\"" 1>&2
		exit 1
	fi
	rm -f $output_xlsx_fn
	if [ -f "$output_xlsx_fn" ]; then
		echo "FAIL: file \"$output_xlsx_fn\" already exists" 1>&2
		exit 1
	fi
	# Use add_worksheet1_metric.ts to append the new fields to the xlsx file.
	ts_node=`pwd`/../node_modules/.bin/ts-node
	if [ ! -f "$ts_node" ]; then
		echo "FAIL: expected file at \"$ts_node\"" 1>&2
		exit 1
	fi
	if $ts_node --project ../tsconfig.json src/add_worksheet1_metric.ts $input_xlsx_fn $csv_fn $output_xlsx_fn; then
		echo "OK $ts_node --project ../tsconfig.json src/add_worksheet1_metric.ts $input_xlsx_fn $csv_fn $output_xlsx_fn" 1>&2
	else
		echo "FAIL $ts_node --project ../tsconfig.json src/add_worksheet1_metric.ts $input_xlsx_fn $csv_fn $output_xlsx_fn" 1>&2
                exit 1
        fi
}

set -o pipefail
t=/tmp/$USER.generate_property_template_spreadsheet
csv_fn=$t.csv
excel_date_12_31_2024=45657
debug_mode=''
dry_mode=''
QAFieldID0=''
QAFieldIDn=''
input_xlsx_fn=''
output_xlsx_fn=''
verbose_mode=''
while [ -n "$1" ]; do
	case "$1" in
		-dry)
			dry_mode=-dry
		;;
		-QAFieldID0)
			shift
			QAFieldID0="$1"
		;;
		-QAFieldIDn)
			shift
			QAFieldIDn="$1"
		;;
		-i|-input_xlsx_fn)
			shift
			input_xlsx_fn="$1"
		;;
		-o|-output_xlsx_fn)
			shift
			output_xlsx_fn="$1"
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
Gen_csv > $csv_fn
Append_new_fields_to_xlsx

exit
$dp/git/a/util/generate_property_template_spreadsheet.sh -QAFieldID0 1 -QAFieldIDn 20 -i $dp/git/a/util/spreadsheets/z.xlsx -o $dp/git/a/util/spreadsheets/z20.xlsx
exit
$dp/git/a/util/generate_property_template_spreadsheet.sh -x -QAFieldID0 1 -QAFieldIDn 2	 -i $dp/git/a/util/spreadsheets/z.xlsx -o $dp/git/a/util/spreadsheets/z2.xlsx
