#!/bin/bash
set -o pipefail
VENV_NAME=$dp/venv_qr311ab
REQUIREMENTS_FILE=$dp/git/fin_doc_parser/server/src/requirements.txt
$dp/git/bin/python.env_create $VENV_NAME $REQUIREMENTS_FILE
. $dp/git/a/util/python.inc

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