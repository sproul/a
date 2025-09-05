#!/bin/bash
script_dir=$(dirname $BASH_SOURCE|sed -e 's;^/$;;')      # if the containing dir is /, scripting goes better if script_dir is ''
set -o pipefail

Extract_IDs_from_csv()
{
        sed -e 's/^"[^"]*//' -e 's/^[^,]*,//' -e 's/,.*//' -e '/QA Field ID/d'
}

cd $script_dir/spreadsheets || exit 1
cat dd.Bank.csv | Extract_IDs_from_csv > dd.Bank.fieldIDs
cat dd.Stock.csv | Extract_IDs_from_csv > dd.Stock.fieldIDs

exit