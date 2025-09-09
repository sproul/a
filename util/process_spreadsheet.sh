#!/bin/bash
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
		if csv.rm_embedded_commas_and_number_quotes.sh -overwrite $spreadsheet_fn; then
			echo "OK csv.rm_embedded_commas_and_number_quotes.sh -overwrite $spreadsheet_fn" 1>&2
		else
			echo "FAIL csv.rm_embedded_commas_and_number_quotes.sh -overwrite $spreadsheet_fn" 1>&2
			exit 1
		fi
                if csv.divide_QA_spreadsheet_by_firm.sh        -overwrite $spreadsheet_fn; then
                        echo "OK csv.divide_QA_spreadsheet_by_firm.sh   -overwrite $spreadsheet_fn" 1>&2
		else
			echo "FAIL csv.divide_QA_spreadsheet_by_firm.sh -overwrite $spreadsheet_fn" 1>&2
                        exit 1
                fi
	;;
	*)
		echo "FAIL require csv format for now, but saw \"$spreadsheet_fn\"" 1>&2
		exit 1
	;;
esac

exit