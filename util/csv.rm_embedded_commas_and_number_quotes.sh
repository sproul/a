#!/bin/bash

Sed()
{
        sed -E -e 's/$/,/' -e 's/([0-9]),([0-9][0-9][0-9](\.[0-9][0-9])?",)/\1\2/g' \
        -e 's/([0-9]),([0-9][0-9][0-9][0-9][0-9][0-9](\.[0-9][0-9])?",)/\1\2/g'	\
        -e 's/([0-9]),([0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9](\.[0-9][0-9])?",)/\1\2/g' \
        -e 's/"(-?[0-9][0-9]*(\.[0-9][0-9])?)"/\1/g' \
        -e 's/,$//'
}

Test1()
{
        local label="$1"; shift
        
        local input="$1"
        local expected="$2"
        local actual=`Sed <<< "$input"`
        if [ "$expected" = "$actual" ]; then
                echo "OK $label $input -> $expected" 1>&2
        else
                echo "FAIL $label $input -> $actual, not $expected" 1>&2
        fi
}


Test()
{
        Test1 basic_bil '"1,234,789,123",ab' 1234789123,ab
        Test1 consec_fractional '1806.73,"1,881.30","2,041.44",' 1806.73,1881.30,2041.44,
        Test1 basic_eoln '"1,234"' 1234
        Test1 basic_mil_eoln '"1,234,789"' 1234789
        Test1 basic_bil_eoln '"1,234,789,123"' 1234789123
        Test1 basic '"1,234",ab' 1234,ab
        Test1 basic_fractional_eoln '"1,234.34"' 1234.34
        Test1 basic_fractional '"1,234.34",ab' 1234.34,ab
        Test1 basic_neg '"-1,234",ab' -1234,ab
        Test1 basic_fractional_neg '"-1,234.34",ab' -1234.34,ab
        Test1 basic_mil '"1,234,789",ab' 1234789,ab
}

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
                -test)
                        Test
                        exit
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

cat $csv_fn | Sed > $csv_fn.new
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
exit
$dp/git/a/util/csv.rm_embedded_commas_and_number_quotes.sh -test