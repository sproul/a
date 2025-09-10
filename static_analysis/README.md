# Financial Metrics Analyzer

A Python program that analyzes financial metrics for banks using RSSD IDs and identifies remarkable changes in the latest quarter compared to historical trends.

## Features

- Analyzes financial metrics from DuckDB/Parquet data sources
- Identifies remarkable changes using sophisticated trend analysis
- Detects trend reversals, accelerations, and significant deviations
- Generates JSON output with expected vs actual changes
- Creates HTML reports using LLM analysis via OpenRouter.ai
- Supports multiple trend analysis criteria:
  - Large deviations from historical patterns (>2 standard deviations)
  - Trend reversals (positive trends turning negative and vice versa)
  - Significant acceleration or deceleration of trends

## Installation

1. Install required dependencies:
```bash
pip install -r requirements.txt
```

2. Ensure you have access to the financial data in DuckDB/Parquet format with the schema defined in `/Users/x/dp/git/a/util/db_schema.sql`

## Usage

### Basic Analysis (JSON output only)
```bash
python financial_analyzer.py <RSSD_ID>
```

### Full Analysis with HTML Report
```bash
python financial_analyzer.py <RSSD_ID> --openrouter-key <YOUR_API_KEY>
```

### Custom Database Path
```bash
python financial_analyzer.py <RSSD_ID> --db-path /path/to/database.db
```

### Custom Output Directory
```bash
python financial_analyzer.py <RSSD_ID> --output-dir /custom/output/path
```

## Example

```bash
python financial_analyzer.py 370631 --openrouter-key sk-or-v1-xxx
```

This will:
1. Analyze all financial metrics for bank with RSSD ID 370631
2. Generate JSON output showing remarkable vs unremarkable changes
3. Create an HTML report using LLM analysis
4. Save the report to `/Users/x/dp/git/a/data/firms_by_rssd_id/370631/report.htm`

## Output Format

The program generates a JSON structure like:

```json
{
    "name": "First Bank and Trust",
    "rssd_id": "370631",
    "remarkable_changes": [
        {
            "Net profit": {
                "expected_change_based_on_trend": "3.7%",
                "actual_change": "21.3%"
            }
        }
    ],
    "unremarkable_changes": [
        {
            "Interest margin": {
                "expected_change_based_on_trend": "0.1%",
                "actual_change": "0.2%"
            }
        }
    ]
}
```

## Algorithm Details

The trend analysis uses multiple criteria to determine if a metric change is remarkable:

1. **Statistical Deviation**: Changes that deviate more than 2 standard deviations from historical patterns
2. **Trend Reversal**: When a consistent positive trend turns negative or vice versa
3. **Acceleration/Deceleration**: Significant changes in the rate of change compared to historical patterns
4. **Linear Regression**: Uses scipy.stats.linregress to predict expected changes based on historical trends

## Requirements

- Python 3.8+
- DuckDB database with financial metrics
- OpenRouter.ai API key (optional, for HTML reports)
- All dependencies listed in requirements.txt

## Database Schema

The program expects data in the format defined by the schema at `/Users/x/dp/git/a/util/db_schema.sql`, with tables:
- `company`: Bank information indexed by RSSD ID
- `financial_metrics`: Time series financial data for each bank
