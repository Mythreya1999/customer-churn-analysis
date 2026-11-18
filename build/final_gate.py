"""Final gate: independent recomputation, SQL cross-check, tier validation, artifact inventory."""
import pandas as pd, sqlite3, os, json

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
df = pd.read_csv(f"{ROOT}/data/raw/customer_churn.csv")
df['TotalCharges'] = pd.to_numeric(df['TotalCharges'], errors='coerce').fillna(0.0)
df['c'] = (df.Churn == 'Yes').astype(int)
n, k = len(df), int(df.c.sum())

print("=== INDEPENDENT RECOMPUTATION (raw CSV) ===")
pandas_vals = {
    'customers': n, 'churners': k,
    'churn_rate_pct': round(100*k/n, 2),
    'mrr_total': round(df.MonthlyCharges.sum(), 2),
    'mrr_churned': round(df.loc[df.c == 1, 'MonthlyCharges'].sum(), 2),
    'arr_exposure': round(df.loc[df.c == 1, 'MonthlyCharges'].sum()*12, 2),
}
for kk, v in pandas_vals.items():
    print(f"  {kk:16s} {v:>16,.2f}")

con = sqlite3.connect(f"{ROOT}/db/churn.db")
kpi = pd.read_sql_query("SELECT * FROM v_kpi_overall", con).iloc[0]
rr = pd.read_sql_query("SELECT * FROM v_revenue_at_risk", con).iloc[0]
tiers = pd.read_sql_query("SELECT * FROM v_priority_tiers ORDER BY priority_tier", con)
sql_vals = {'customers': int(kpi.customers), 'churners': int(kpi.churners),
            'churn_rate_pct': float(kpi.churn_rate_pct), 'mrr_total': float(kpi.mrr_total),
            'mrr_churned': float(kpi.mrr_churned), 'arr_exposure': float(rr.arr_exposure)}

print("\n=== CROSS-LAYER (pandas vs SQL views) ===")
print(f"{'metric':18s} {'pandas':>16s} {'sql':>16s} {'match':>7s}")
allok = True
for kk in pandas_vals:
    a, b = pandas_vals[kk], sql_vals[kk]
    ok = abs(a-b) < 0.011
    allok &= ok
    print(f"{kk:18s} {a:>16,.2f} {b:>16,.2f} {str(ok):>7s}")
print("ALL MATCH" if allok else "*** MISMATCH ***")

print("\n=== TIER VALIDATION ===")
print(tiers[['priority_tier', 'customers', 'churners', 'churn_rate_pct',
             'pct_of_all_churners', 'mrr_lost']].to_string(index=False))
tiers_ok = (tiers.customers.sum() == n and tiers.churners.sum() == k
            and tiers.churn_rate_pct.is_monotonic_decreasing)
print("tiers sum to base & churners, and are monotone:", tiers_ok)

print("\n=== DASHBOARD PAYLOAD vs SQL ===")
payload = json.load(open(f"{ROOT}/build/dash_payload.json"))
print(f"  rows: {len(payload['rows'])} (expect {n}) ->", len(payload['rows']) == n)
print(f"  expected block: {payload['expected']}")

print("\n=== ARTIFACT INVENTORY ===")
need = [
    'README.md', 'requirements.txt', '.gitignore',
    'data/raw/customer_churn.csv', 'data/processed/customer_churn_cleaned.csv',
    'data/processed/customer_churn_scored.csv',
    'python/customer_churn_eda.ipynb',
    'sql/01_data_exploration.sql', 'sql/02_churn_analysis.sql',
    'sql/03_customer_segmentation.sql', 'sql/04_retention_insights.sql',
    'powerbi/customer_churn_dashboard.html', 'powerbi/POWERBI_BUILD_GUIDE.md',
    'powerbi/dax_measures.dax', 'powerbi/model/fact_churn.csv', 'powerbi/model/dim_customer.csv',
    'powerbi/model/dim_contract.csv', 'powerbi/model/dim_service.csv', 'powerbi/model/dim_tenure.csv',
    'screenshots/executive_dashboard.png', 'screenshots/churn_drivers.png',
    'screenshots/retention_analysis.png',
    'reports/KPI_DEFINITIONS.md', 'reports/DATASET_DECISION.md', 'reports/ORIGINAL_FILE_AUDIT.md',
    'reports/_analysis_numbers.md',
    'reports/sql/01_data_exploration.md', 'reports/sql/02_churn_analysis.md',
    'reports/sql/03_customer_segmentation.md', 'reports/sql/04_retention_insights.md',
    'db/churn.db',
]
missing = []
for f in need:
    path = f"{ROOT}/{f}"
    ex = os.path.exists(path)
    print(f"  {'OK  ' if ex else 'MISS'} {f:44s} {os.path.getsize(path) if ex else 0:>10,} bytes")
    if not ex:
        missing.append(f)
figs = sorted(os.listdir(f"{ROOT}/reports/figures"))
print(f"  figures: {len(figs)} -> {figs}")

print("\nMISSING:", missing if missing else "none")
con.close()
json.dump({'pandas': pandas_vals, 'sql': sql_vals, 'missing': missing,
           'tiers_ok': bool(tiers_ok)},
          open(f"{ROOT}/build/final_gate.json", 'w'), indent=2)
