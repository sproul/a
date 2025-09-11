#!/usr/bin/env bash
# given a spreadsheet, split the data out by firm and save the resulting firm-specific slice at $dp/git/a/public/firms_by_rssd_id/-512/YYYY-MM-DD.csv
#
# This makes it easy to see if the data have been updated (and therefore a new static report should be generated.
#
# This also raises the possibility of reporting what fields were updated, since that also is easy to extract.
# 
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
                *)
                        break
                ;;
        esac
        shift
done
rssd_id="$1"
csv_fn="$2"

awk -v rssd_id="$rssd_id" -F, '
NR==1 {
    keep[1]=keep[2]=keep[3]=1        # always keep first 3
    for (i=4; i<=NF; i++) {
        if ($i == rssd_id) keep[i]=1
    }
}
{
    out=""
    for (i=1; i<=NF; i++) {
        if (keep[i]) {
            if (out=="") out=$i; else out=out FS $i
        }
    }
    print out
}' "$csv_fn"
exit
$dp/git/a/util/csv.extract_QA_spreadsheet_data_for_rssd_id.sh -x -512 $dp/git/a/util/spreadsheets/test_minimal.csv >  $dp/git/a/util/spreadsheets/test_minimal.csv.new
diff $dp/git/a/util/spreadsheets/test_minimal.csv $dp/git/a/util/spreadsheets/test_minimal.csv.new
exit
$dp/git/a/util/csv.extract_QA_spreadsheet_data_for_rssd_id.sh -x -1024 $dp/git/a/util/spreadsheets/test_minimal.csv >  $dp/git/a/util/spreadsheets/test_minimal.csv.new
diff $dp/git/a/util/spreadsheets/test_minimal.csv $dp/git/a/util/spreadsheets/test_minimal.csv.new
