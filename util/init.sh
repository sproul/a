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

# Create DuckDB views for financial data
duckdb $dp/git/a/data/mydb.duckdb << EOF
-- Create view for financial metrics from parquet file
CREATE OR REPLACE VIEW financial_metrics AS 
SELECT 
    rssd_id,
    company_name,
    type,
    property_name,
    qa_field_id,
    field_type,
    period_date,
    duration,
    value
FROM read_parquet('$dp/git/a/data/financial_metrics.parquet');

-- Create view for company information (extracted from financial_metrics)
CREATE OR REPLACE VIEW company AS
SELECT DISTINCT 
    rssd_id,
    company_name,
    type,
    'Unknown' as city,
    'Unknown' as state
FROM read_parquet('$dp/git/a/data/financial_metrics.parquet')
WHERE company_name IS NOT NULL AND company_name != '';

-- Create view for ticker to RSSD ID mapping
CREATE OR REPLACE VIEW ticker_to_rssd AS
SELECT 
    ticker,
    "RSSD ID" as rssd_id
FROM read_parquet('$dp/git/a/data/ticker_to_rssd.parquet');
EOF
