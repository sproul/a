#!/bin/bash
script_dir=$(dirname $BASH_SOURCE|sed -e 's;^/$;;')      # if the containing dir is /, scripting goes better if script_dir is ''
export PATH=$script_dir:$PATH

Duplicate_string_for_each_quarter()
{
        local s="$1"
        printf ",%s,%s,%s,%s,%s,%s" "$s" "$s" "$s" "$s" "$s" "$s"
}

Gen_csv()
{
        printf ',,RSSD ID'
        rssd_ids.sh -$firm_count_from_rssd_ids > $t.1
        firm_count_from_rssd_ids=`wc -l $t.1 | sed -e 's/^ *//' -e 's/ .*//'`   #       needed in case firm_count_from_rssd_ids was -all_non_test
        while read rssd_id; do
                Duplicate_string_for_each_quarter "$rssd_id"
        done < $t.1
        echo ''

        printf ,,Name
        (( i = 0 ))
        while [ $i -lt $firm_count_from_rssd_ids ]; do
                Duplicate_string_for_each_quarter ''
                (( i++ ))
        done 
        echo ''
        
        printf ,,Type
        (( i = 0 ))
        while [ $i -lt $firm_count_from_rssd_ids ]; do
                Duplicate_string_for_each_quarter Bank
                (( i++ ))
        done
        echo ''
        
        printf ,,Period
        (( i = 0 ))
        while [ $i -lt $firm_count_from_rssd_ids ]; do
                printf ,3/31/2024,6/30/2024,9/30/2024,12/31/2024,3/31/2025,6/30/2025
                (( i++ ))
        done
        echo ''
        
        printf ,,Duration
        (( i = 0 ))
        while [ $i -lt $firm_count_from_rssd_ids ]; do
                Duplicate_string_for_each_quarter MRQ
                (( i++ ))
        done
        echo ''
        cat $script_dir/spreadsheets/fsb_combined_base.csv
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
cd $dp/git/a/util/spreadsheets
t=/tmp/$USER.generate_property_template_spreadsheet
fields_to_add_csv_fn=$t.csv
excel_date_12_31_2024=45657
debug_mode=''
dry_mode=''
QAFieldID0=''
QAFieldIDn=''
firm_count_from_rssd_ids=''
input_base_csv_fn=''
output_csv_fn=''
verbose_mode=''
while [ -n "$1" ]; do
	case "$1" in
                -all)
                        cd $dp/git/a/util/spreadsheets
                        bank_field_count=`wc -l $dp/git/a/util/spreadsheets/dd.Bank.fieldIDs | sed -e 's/^ *//' -e 's/ .*//'`
                        if [ -n "$bank_field_count" ]; then
                                echo "OK_field_count = $bank_field_count" 1>&2
                        else
                                echo "FAIL unexpectedly saw no value for bank_field_count" 1>&2
                                exit 1
                        fi
                        # we have a canonical set of metrics in fsb_combined_base.csv. These separate counts reflect how
                        # many firms are added (drawing from siena_rssd_ids.csv)
                        $0 $debug_mode -firm_count_from_rssd_ids 1                 -o    fsb_generated_1.csv || exit 1
                        $0 $debug_mode -firm_count_from_rssd_ids 2                 -o    fsb_generated_2.csv || exit 1
                        
                        #$0 $debug_mode -QAFieldID0 1 -QAFieldIDn 2                 -o    fsb_generated_3.csv || exit 1
                        #$0 $debug_mode -QAFieldID0 1 -QAFieldIDn 20                -o   fsb_generated_20.csv || exit 1
                        #$0 $debug_mode -QAFieldID0 1 -QAFieldIDn 100               -o  fsb_generated_100.csv || exit 1
                        #$0 $debug_mode -QAFieldID0 1 -QAFieldIDn 500               -o  fsb_generated_500.csv || exit 1
                        #$0 $debug_mode -QAFieldID0 1 -QAFieldIDn $bank_field_count -o fsb_generated__all.csv || exit 1
                        exit 0
                ;;
                -all_non_test)
                        $0 $debug_mode -firm_count_from_rssd_ids all_non_test -o fsb_generated_all_non_test.csv || exit 1
                        exit 0
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
                -firm_count_from_rssd_ids)
                        shift
                        firm_count_from_rssd_ids="$1"
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
if [ -z "$input_base_csv_fn" ]; then
        echo "OK confirmed no value for input_base_csv_fn, so writing the addition to $output_csv_fn" 1>&2
        Gen_csv > $output_csv_fn
else
        Gen_csv > $fields_to_add_csv_fn
        Append_new_fields_to_csv
fi
ls -l `pwd`/$output_csv_fn

exit
$dp/git/a/util/generate_property_template_spreadsheet.sh -QAFieldID0 1 -QAFieldIDn 20 -i $dp/git/a/util/spreadsheets/z.csv -o $dp/git/a/util/spreadsheets/z20.csv
$dp/git/a/util/generate_property_template_spreadsheet.sh -x -QAFieldID0 1 -QAFieldIDn 2 -o y3.csv
$dp/git/a/util/generate_property_template_spreadsheet.sh -x -all
exit
$dp/git/a/util/generate_property_template_spreadsheet.sh -x -all_non_test