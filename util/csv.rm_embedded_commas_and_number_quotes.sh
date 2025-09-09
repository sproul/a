#!/bin/bash
set -o pipefail
debug_mode=''
dry_mode=''
overwrite_mode=''
t=`mktemp`; trap "rm $t*" EXIT
verbose_mode=''
while [ -n "$1" ]; do
	case "$1" in
		-dry)
			dry_mode=-dry
		;;
		-overwrite)
			overwrite_mode=-overwrite
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
cat $csv_fn | sed -e 's/\([0-9]\),\([0-9][0-9][0-9]",\)/\1\2/g' \
-e 's/\([0-9]\),\([0-9][0-9][0-9][0-9][0-9][0-9]",\)/\1\2/g'	\
-e 's/\([0-9]\),\([0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]",\)/\1\2/g' \
-e 's/"\([0-9][0-9]*\)"/\1/g' > $csv_fn.new
echo "diff $csv_fn $csv_fn.new"
diff	   $csv_fn $csv_fn.new
if [ -n "$overwrite_mode" ]; then
	if mv $csv_fn /tmp; then
		echo "OK mv $csv_fn /tmp" 1>&2
	else
		echo "FAIL mv $csv_fn /tmp" 1>&2
		exit 1
	fi
        if mv $csv_fn.new $csv_fn; then
		echo "OK mv $csv_fn.new $csv_fn" 1>&2
	else
		echo "FAIL mv $csv_fn.new $csv_fn" 1>&2
                exit 1
        fi
fi
exit
$dp/git/a/util/csv.rm_embedded_commas_and_number_quotes.sh $t