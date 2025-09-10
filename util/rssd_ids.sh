#!/bin/bash

Sed_filter_to_rssd_id()
{
        sed -e /^ticker,/d -e 's/.*,//'
}

Sed_filter_to_ticker()
{
        sed -e /^ticker,/d -e 's/,.*//'
}

Get_rssd_id_from_ticker()
{
        ticker=$1
        if [ -z "$ticker" ]; then
                echo "FAIL: expected a value for \"ticker\" but saw nothing" 1>&2
                exit 1
        fi
        rssd_id=`grep ^$ticker, $rssd_id_fn | Sed_filter_to_rssd_id`
        if [ -z "$rssd_id" ]; then
                echo "FAIL: rssd_ids.sh: $ticker not found" 1>&2
                exit 1
        fi
        echo $rssd_id
}

Get_ticker_from_rssd_id()
{
        rssd_id=$1
        if [ -z "$rssd_id" ]; then
                echo "FAIL: expected a value for \"rssd_id\" but saw nothing" 1>&2
                exit 1
        fi
        ticker=`grep ",$rssd_id$" $rssd_id_fn | Sed_filter_to_ticker`
        if [ -z "$ticker" ]; then
                echo "FAIL: rssd_ids.sh: $ticker not found" 1>&2
                exit 1
        fi
        echo $ticker
}


script_dir=$(dirname $BASH_SOURCE|sed -e 's;^/$;;')      # if the containing dir is /, scripting goes better if script_dir is ''
set -o pipefail
debug_mode=''
dry_mode=''
rssd_id_fn=$script_dir/spreadsheets/tickers_and_rssd_ids.csv
t=`mktemp`; trap "rm $t*" EXIT
verbose_mode=''
while [ -n "$1" ]; do
        case "$1" in
                -[0-9]*)
                        cat $rssd_id_fn | Sed_filter_to_rssd_id | head $1
                        exit 0
                ;;
                -all_non_test)
                        cat $rssd_id_fn | sed -e '/,-[0-9][0-9]*$/d' | Sed_filter_to_rssd_id
                        exit 0
                ;;
                -dry)
                        dry_mode=-dry
                ;;
                -from_rssd_id)
                        shift
                        rssd_id=$1
                        Get_ticker_from_rssd_id $rssd_id
                        exit
                ;;
                -from_ticker)
                        shift
                        ticker=$1
                        Get_rssd_id_from_ticker $ticker
                        exit
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
echo "FAIL no op" 1>&2
exit 1


exit
$dp/git/a/util/rssd_ids.sh -from_ticker CMA
$dp/git/a/util/rssd_ids.sh -from_rssd_id 1199844
$dp/git/a/util/rssd_ids.sh -5
exit
$dp/git/a/util/rssd_ids.sh -all_non_test