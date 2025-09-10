#!/bin/bash
script_dir=$(dirname $BASH_SOURCE|sed -e 's;^/$;;')      # if the containing dir is /, scripting goes better if script_dir is ''
export PATH=$script_dir:$script_dir/../util:$PATH
set -o pipefail
debug_mode=''
dry_mode=''
t=`mktemp`; trap "rm $t*" EXIT
verbose_mode=''
. python.inc
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
python3 financial_analyzer.py $*
exit
$dp/git/a/static_analysis/financial_analyzer.sh -x 