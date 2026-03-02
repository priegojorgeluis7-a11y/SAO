"""
Load Testing Results Analyzer

Analyzes Locust CSV results and generates a summary report

Usage: python analyze_results.py <results_directory>
       python analyze_results.py load_tests/results/

Output: Summary statistics, pass/fail criteria, recommendations
"""

import pandas as pd
import sys
from pathlib import Path
from datetime import datetime

def analyze_csv(csv_file):
    """Analyze Locust CSV results"""
    
    print(f"\n📊 Analyzing: {csv_file.name}")
    print("=" * 70)
    
    try:
        df = pd.read_csv(csv_file)
    except Exception as e:
        print(f"❌ Error reading file: {e}")
        return
    
    # Summary stats
    total_requests = len(df)
    failed_requests = len(df[df['Failure Type'].notna()])
    failure_rate = (failed_requests / total_requests * 100) if total_requests > 0 else 0
    
    print(f"\n📈 Summary Statistics:")
    print(f"  Total Requests: {total_requests:,}")
    print(f"  Successful: {total_requests - failed_requests:,}")
    print(f"  Failed: {failed_requests:,} ({failure_rate:.2f}%)")
    
    # Response time percentiles
    print(f"\n⏱️  Response Time Percentiles:")
    print(f"  Mean: {df['Response Times'].mean():,.0f}ms")
    print(f"  Median (p50): {df['Response Times'].quantile(0.50):,.0f}ms")
    print(f"  p75: {df['Response Times'].quantile(0.75):,.0f}ms")
    print(f"  p95: {df['Response Times'].quantile(0.95):,.0f}ms")
    print(f"  p99: {df['Response Times'].quantile(0.99):,.0f}ms")
    print(f"  Max: {df['Response Times'].max():,.0f}ms")
    
    # Performance checks
    print(f"\n✅ Performance Checks:")
    p95 = df['Response Times'].quantile(0.95)
    if p95 < 500:
        print(f"  ✅ p95 < 500ms: {p95:.0f}ms PASS")
    elif p95 < 2000:
        print(f"  ⚠️  p95 < 2s: {p95:.0f}ms PASS (but slower than ideal)")
    else:
        print(f"  ❌ p95 < 2s: {p95:.0f}ms FAIL")
    
    if failure_rate < 0.1:
        print(f"  ✅ Error rate < 0.1%: {failure_rate:.2f}% PASS")
    elif failure_rate < 1.0:
        print(f"  ⚠️  Error rate < 1%: {failure_rate:.2f}% PASS (but high)")
    else:
        print(f"  ❌ Error rate < 1%: {failure_rate:.2f}% FAIL")
    
    # By endpoint
    print(f"\n🔍 By Endpoint:")
    for endpoint in sorted(df['Name'].unique()):
        if pd.isna(endpoint):
            continue
        ep_data = df[df['Name'] == endpoint]
        ep_failed = len(ep_data[ep_data['Failure Type'].notna()])
        ep_failure_rate = (ep_failed / len(ep_data) * 100) if len(ep_data) > 0 else 0
        
        print(f"\n  {endpoint}:")
        print(f"    Requests: {len(ep_data):,}")
        print(f"    Avg Response: {ep_data['Response Times'].mean():,.0f}ms")
        print(f"    p95: {ep_data['Response Times'].quantile(0.95):,.0f}ms")
        print(f"    Failures: {ep_failed} ({ep_failure_rate:.2f}%)")
    
    # Overall verdict
    print(f"\n🎯 Overall Verdict:")
    if failure_rate < 0.1 and failure_rate < 2000:
        print("  ✅ PASS - System ready for production")
    elif failure_rate < 1.0 and p95 < 5000:
        print("  ⚠️  CONDITIONAL PASS - Monitor closely")
    else:
        print("  ❌ FAIL - Issues need resolution")
    
    print("=" * 70)


def main():
    """Main entry point"""
    
    if len(sys.argv) < 2:
        print("📊 Load Testing Results Analyzer")
        print("Usage: python analyze_results.py <results_directory>")
        print("Example: python analyze_results.py load_tests/results/")
        sys.exit(1)
    
    results_dir = Path(sys.argv[1])
    
    if not results_dir.exists():
        print(f"❌ Directory not found: {results_dir}")
        sys.exit(1)
    
    print(f"\n🔍 Analyzing results from: {results_dir}")
    print(f"📅 Time: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    
    csv_files = list(results_dir.glob("**/*.csv"))
    
    if not csv_files:
        print(f"❌ No CSV files found in {results_dir}")
        sys.exit(1)
    
    print(f"Found {len(csv_files)} result file(s)")
    
    for csv_file in sorted(csv_files):
        analyze_csv(csv_file)
    
    print(f"\n✅ Analysis complete!")
    print(f"\n📞 Next Steps:")
    print(f"  1. Review results above")
    print(f"  2. If PASS: Ready to deploy")
    print(f"  3. If FAIL: Identify bottleneck and optimize")
    print(f"  4. If CONDITIONAL: Monitor in production")


if __name__ == "__main__":
    main()
