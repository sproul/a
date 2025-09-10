#!/usr/bin/env python3
"""
Financial Metrics Analyzer for Banks

This program analyzes financial metrics for a given bank (by RSSD ID) and identifies
remarkable changes in the latest quarter compared to historical trends.
"""

import argparse
import json
import os
import sys
from datetime import datetime
from pathlib import Path
from typing import Dict, List, Tuple, Optional, Any
import warnings

import duckdb
import numpy as np
import pandas as pd
from scipy import stats
from langchain_openai import ChatOpenAI
from langchain_core.messages import HumanMessage

warnings.filterwarnings('ignore')


class FinancialAnalyzer:
    """Analyzes financial metrics for banks using DuckDB/Parquet data."""
    
    def __init__(self, db_path: str = None):
        """Initialize the analyzer with database connection."""
        self.conn = duckdb.connect(db_path) if db_path else duckdb.connect()
        
    def get_bank_info(self, rssd_id: str) -> Dict[str, str]:
        """Get basic bank information."""
        query = """
        SELECT company_name, rssd_id, type, city, state
        FROM company 
        WHERE rssd_id = ?
        """
        result = self.conn.execute(query, [rssd_id]).fetchone()
        if not result:
            raise ValueError(f"Bank with RSSD ID {rssd_id} not found")
        
        return {
            "name": result[0],
            "rssd_id": str(result[1]),
            "type": result[2],
            "city": result[3],
            "state": result[4]
        }
    
    def get_financial_metrics(self, rssd_id: str) -> pd.DataFrame:
        """Get all financial metrics for a bank, sorted by date."""
        query = """
        SELECT 
            property_name,
            qa_field_id,
            field_type,
            period_date,
            duration,
            value,
            company_name
        FROM financial_metrics 
        WHERE rssd_id = ? 
        AND value IS NOT NULL 
        AND value != ''
        ORDER BY property_name, qa_field_id, field_type, period_date
        """
        
        df = self.conn.execute(query, [rssd_id]).df()
        
        # Convert value to numeric where possible
        df['numeric_value'] = pd.to_numeric(df['value'], errors='coerce')
        df['period_date'] = pd.to_datetime(df['period_date'])
        
        # Filter out non-numeric values for trend analysis
        df = df.dropna(subset=['numeric_value'])
        
        return df
    
    def analyze_metric_trend(self, values: np.ndarray, dates: np.ndarray) -> Dict[str, Any]:
        """
        Analyze trend in a metric series and determine if latest value is remarkable.
        
        Returns:
            Dict containing trend analysis results
        """
        if len(values) < 3:
            return {
                "trend_type": "insufficient_data",
                "expected_change": 0.0,
                "actual_change": 0.0,
                "is_remarkable": False,
                "confidence": 0.0
            }
        
        # Calculate period-over-period changes
        changes = np.diff(values) / values[:-1] * 100  # Percentage changes
        
        if len(changes) < 2:
            return {
                "trend_type": "insufficient_data",
                "expected_change": 0.0,
                "actual_change": changes[0] if len(changes) > 0 else 0.0,
                "is_remarkable": False,
                "confidence": 0.0
            }
        
        # Latest actual change
        actual_change = changes[-1]
        
        # Analyze historical trend
        if len(changes) >= 3:
            # Use linear regression on changes to predict next change
            x = np.arange(len(changes[:-1]))
            y = changes[:-1]
            
            if len(x) > 1 and np.std(y) > 0:
                slope, intercept, r_value, p_value, std_err = stats.linregress(x, y)
                expected_change = slope * len(x) + intercept
                trend_strength = abs(r_value)
            else:
                expected_change = np.mean(changes[:-1])
                trend_strength = 0.0
        else:
            expected_change = changes[0]
            trend_strength = 0.0
        
        # Calculate deviation from expected
        deviation = abs(actual_change - expected_change)
        historical_std = np.std(changes[:-1]) if len(changes) > 2 else abs(actual_change)
        
        # Determine if remarkable based on multiple criteria
        is_remarkable = False
        confidence = 0.0
        
        # Criterion 1: Large deviation from trend (>2 standard deviations)
        if historical_std > 0:
            z_score = deviation / historical_std
            if z_score > 2.0:
                is_remarkable = True
                confidence = min(z_score / 4.0, 1.0)  # Scale confidence
        
        # Criterion 2: Trend reversal
        if len(changes) >= 3:
            recent_trend = np.mean(changes[-3:-1])  # Trend before latest
            if (recent_trend > 1 and actual_change < -1) or (recent_trend < -1 and actual_change > 1):
                is_remarkable = True
                confidence = max(confidence, 0.8)
        
        # Criterion 3: Acceleration/deceleration
        if len(changes) >= 4:
            acceleration = changes[-1] - changes[-2]
            historical_acceleration_std = np.std(np.diff(changes[:-1]))
            if historical_acceleration_std > 0 and abs(acceleration) > 2 * historical_acceleration_std:
                is_remarkable = True
                confidence = max(confidence, 0.7)
        
        # Determine trend type
        if trend_strength > 0.7:
            if expected_change > 0:
                trend_type = "strong_positive"
            else:
                trend_type = "strong_negative"
        elif trend_strength > 0.3:
            if expected_change > 0:
                trend_type = "weak_positive"
            else:
                trend_type = "weak_negative"
        else:
            trend_type = "no_clear_trend"
        
        return {
            "trend_type": trend_type,
            "expected_change": expected_change,
            "actual_change": actual_change,
            "is_remarkable": is_remarkable,
            "confidence": confidence,
            "trend_strength": trend_strength,
            "deviation": deviation
        }
    
    def analyze_all_metrics(self, rssd_id: str) -> Dict[str, Any]:
        """Analyze all metrics for a bank and categorize remarkable vs unremarkable changes."""
        
        bank_info = self.get_bank_info(rssd_id)
        df = self.get_financial_metrics(rssd_id)
        
        if df.empty:
            raise ValueError(f"No financial data found for RSSD ID {rssd_id}")
        
        remarkable_changes = []
        unremarkable_changes = []
        
        # Group by metric (property_name + qa_field_id + field_type)
        metric_groups = df.groupby(['property_name', 'qa_field_id', 'field_type'])
        
        for (property_name, qa_field_id, field_type), group in metric_groups:
            if len(group) < 2:
                continue
                
            # Sort by date and get values
            group_sorted = group.sort_values('period_date')
            values = group_sorted['numeric_value'].values
            dates = group_sorted['period_date'].values
            
            # Skip if not enough data points
            if len(values) < 2:
                continue
            
            # Analyze trend
            analysis = self.analyze_metric_trend(values, dates)
            
            # Create metric name
            metric_name = property_name
            if qa_field_id and qa_field_id != property_name:
                metric_name += f" ({qa_field_id})"
            
            # Format the result
            metric_result = {
                metric_name: {
                    "expected_change_based_on_trend": f"{analysis['expected_change']:.1f}%",
                    "actual_change": f"{analysis['actual_change']:.1f}%"
                }
            }
            
            # Categorize as remarkable or unremarkable
            if analysis['is_remarkable']:
                remarkable_changes.append(metric_result)
            else:
                unremarkable_changes.append(metric_result)
        
        return {
            "name": bank_info["name"],
            "rssd_id": bank_info["rssd_id"],
            "remarkable_changes": remarkable_changes,
            "unremarkable_changes": unremarkable_changes
        }


class ReportGenerator:
    """Generates HTML reports using LLM analysis."""
    
    def __init__(self, openrouter_api_key: str):
        """Initialize with OpenRouter API key."""
        self.llm = ChatOpenAI(
            model="anthropic/claude-3-sonnet-20240229",
            openai_api_key=openrouter_api_key,
            openai_api_base="https://openrouter.ai/api/v1",
            temperature=0.1
        )
    
    def generate_report(self, analysis_data: Dict[str, Any]) -> str:
        """Generate HTML report using LLM analysis."""
        
        prompt = f"""
You are a skilled bank analyst. Summarize the given financial metric data for this bank, noting the overall trend of the bank's business (if there is one) whether positive or negative. If there are multiple metrics which support each other, note that, e.g.: "Several metrics indicate a deterioration in loan quality, consistent with the decline in profit that has reversed the previous trend." If metrics contradict each other, that also should be noted: "A sharp decline in loan quality makes the stellar increase in profit all the more mysterious." If seeming contradictions can be explained by other metrics, then please explain. If the metrics are simply inconsistent with each other, that also would be worth noting.

If the LLM is capable of producing inline graphs of key financial metrics, it should do so. If it can't do that, but believes such graphs would be helpful, simply include placeholders in the report text, e.g., {{graph "Net profit"}}.

Please generate a minimally styled HTML report. Use simple HTML tags and inline CSS for basic styling.

Financial Data:
{json.dumps(analysis_data, indent=2)}
"""
        
        message = HumanMessage(content=prompt)
        response = self.llm.invoke([message])
        
        return response.content


def main():
    """Main function to run the financial analysis."""
    parser = argparse.ArgumentParser(description='Analyze financial metrics for a bank by RSSD ID')
    parser.add_argument('rssd_id', type=str, help='RSSD ID of the bank to analyze')
    parser.add_argument('--db-path', type=str, help='Path to DuckDB database file')
    parser.add_argument('--openrouter-key', type=str, help='OpenRouter API key for LLM analysis')
    parser.add_argument('--output-dir', type=str, default='/Users/x/dp/git/a/data/firms_by_rssd_id',
                       help='Output directory for reports')
    
    args = parser.parse_args()
    
    try:
        # Initialize analyzer
        analyzer = FinancialAnalyzer(args.db_path)
        
        # Perform analysis
        print(f"Analyzing financial metrics for RSSD ID: {args.rssd_id}")
        analysis_result = analyzer.analyze_all_metrics(args.rssd_id)
        
        # Print JSON result
        print("\nAnalysis Result:")
        print(json.dumps(analysis_result, indent=2))
        
        # Generate HTML report if API key provided
        if args.openrouter_key:
            print("\nGenerating HTML report...")
            report_generator = ReportGenerator(args.openrouter_key)
            html_report = report_generator.generate_report(analysis_result)
            
            # Save report
            output_dir = Path(args.output_dir) / args.rssd_id
            output_dir.mkdir(parents=True, exist_ok=True)
            report_path = output_dir / "report.htm"
            
            with open(report_path, 'w', encoding='utf-8') as f:
                f.write(html_report)
            
            print(f"Report saved to: {report_path}")
        else:
            print("\nNo OpenRouter API key provided. Skipping HTML report generation.")
            print("To generate HTML reports, provide --openrouter-key argument.")
    
    except Exception as e:
        print(f"Error: {e}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
