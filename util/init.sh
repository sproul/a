#!/bin/bash
script_dir=$(dirname $BASH_SOURCE|sed -e 's;^/$;;')      # if the containing dir is /, scripting goes better if script_dir is ''
set -o pipefail
VENV_NAME=$dp/venv_qr311ab
REQUIREMENTS_FILE=$dp/git/fin_doc_parser/server/src/requirements.txt
$dp/git/bin/python.env_create $VENV_NAME $REQUIREMENTS_FILE
. $script_dir/python.inc

case "$OS" in
        mac)
                brew install duckdb
        ;;
        *)
                echo "FAIL did not recognize OS \"$OS\" -- how to install duckdb here?" 1>&2
                exit 1
        ;;
esac
exit