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

Append_new_fields_to_csv()
{
	# Take the csv file and append the new fields to the csv file, extending the spreadsheet to the right.
	if [ ! -r "$fields_to_add_csv_fn" ]; then
		echo "FAIL: expected readable file at \"$fields_to_add_csv_fn\"" 1>&2
		exit 1
	fi
	if [ ! -r "$input_base_csv_fn" ]; then
		echo "FAIL: expected readable file at \"$input_base_csv_fn\"" 1>&2
		exit 1
	fi
	rm -f $output_csv_fn
	if [ -f "$output_csv_fn" ]; then
		echo "FAIL: file \"$output_csv_fn\" already exists" 1>&2
		exit 1
	fi
        if csv_concat_right $input_base_csv_fn $fields_to_add_csv_fn > $output_csv_fn; then
		echo "OK csv_concat_right $input_base_csv_fn $fields_to_add_csv_fn" 1>&2
	else
		echo "FAIL csv_concat_right $input_base_csv_fn $fields_to_add_csv_fn" 1>&2
                cat $output_csv_fn
                exit 1
        fi
        if [ ! -f "$output_csv_fn" ]; then
                echo "FAIL: expected file at \"$output_csv_fn\"" 1>&2
                exit 1
        else
                echo "OK generated $output_csv_fn" 1>&2
        fi
}

set -o pipefail
t=/tmp/$USER.generate_property_template_spreadsheet
fields_to_add_csv_fn=$t.csv
excel_date_12_31_2024=45657
debug_mode=''
dry_mode=''
QAFieldID0=''
QAFieldIDn=''
input_base_csv_fn=''
output_csv_fn=''
verbose_mode=''
while [ -n "$1" ]; do
	case "$1" in
                -all)
                        cd $dp/git/a/util/spreadsheets
                        $0 -x -QAFieldID0 1 -QAFieldIDn 2	 -i y1.csv -o y3.csv
                        $0 -x -QAFieldID0 1 -QAFieldIDn 20	 -i y1.csv -o y20.csv
                        $0 -x -QAFieldID0 1 -QAFieldIDn 100	 -i y1.csv -o y100.csv
                        $0 -x -QAFieldID0 1 -QAFieldIDn 500	 -i y1.csv -o y500.csv
                        $0 -x -QAFieldID0 1 -QAFieldIDn 2000	 -i y1.csv -o y2000.csv
                        $0 -x -QAFieldID0 1 -QAFieldIDn 5000	 -i y1.csv -o y5000.csv
                ;;
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
		-i|-input_base_csv_fn)
			shift
			input_base_csv_fn="$1"
		;;
		-o|-output_csv_fn)
			shift
			output_csv_fn="$1"
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
Gen_csv > $fields_to_add_csv_fn
Append_new_fields_to_csv

exit
$dp/git/a/util/generate_property_template_spreadsheet.sh -QAFieldID0 1 -QAFieldIDn 20 -i $dp/git/a/util/spreadsheets/z.csv -o $dp/git/a/util/spreadsheets/z20.csv
exit
$dp/git/a/util/generate_property_template_spreadsheet.sh -x -QAFieldID0 1 -QAFieldIDn 2	 -i $dp/git/a/util/spreadsheets/y1.csv -o $dp/git/a/util/spreadsheets/z3.csv
