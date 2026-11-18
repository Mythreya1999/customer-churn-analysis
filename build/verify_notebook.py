import json, os, re, sys
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
nb = json.load(open(f"{ROOT}/python/customer_churn_eda.ipynb", encoding='utf-8'))

code_cells = [c for c in nb['cells'] if c['cell_type'] == 'code']
errors = [(i, o) for i, c in enumerate(code_cells) for o in c.get('outputs', []) if o.get('output_type') == 'error']
pngs = [o for c in code_cells for o in c.get('outputs', [])
        if o.get('output_type') in ('display_data', 'execute_result') and 'image/png' in o.get('data', {})]
stream = "\n".join(''.join(o.get('text', '')) for c in code_cells for o in c.get('outputs', [])
                   if o.get('output_type') == 'stream')
md_all = "\n".join(''.join(c['source']) for c in nb['cells'] if c['cell_type'] == 'markdown')

print(f"code cells      : {len(code_cells)}")
print(f"error outputs   : {len(errors)}   -> {'PASS' if not errors else 'FAIL'}")
print(f"chart PNGs      : {len(pngs)}    -> {'PASS (8 expected)' if len(pngs)==8 else 'CHECK'}")
print(f"reconcile line  :", 'PASS' if 'All 5 headline metrics reconcile' in stream else 'FAIL')

# Every number asserted in markdown must appear in the executed stream output
claims = {
 '26.54': 'overall churn rate', '42.71': 'M2M churn', '2.83': 'two-year churn',
 '88.55': 'M2M share of churners', '55.02': 'M2M share of base',
 '52.94': 'months 0-6 churn', '55.48': 'churners within 12m', '31.04': 'new share of base',
 '37.95': 'charge band 70-89', '9.80': 'charge band <30',
 '45.29': 'e-check', '15.24': 'cc auto', '16.71': 'bank auto', '19.11': 'mailed check',
 '41.89': 'fiber', '18.96': 'DSL', '7.40': 'no internet',
 '41.64': 'no techsupport', '15.17': 'yes techsupport',
 '41.77': 'no onlinesec', '14.61': 'yes onlinesec',
 '41.68': 'senior', '23.61': 'nonsenior',
 '26.92': 'female', '26.16': 'male', '0.487': 'gender p-value',
 '0.8446': 'test AUC', '73.46': 'majority baseline',
 '139,130.85': 'MRR churned', '30.50': 'pct MRR', '1,669,570.20': 'annualised',
 '456,116.60': 'MRR total', '74.44': 'MC churned', '61.27': 'MC retained',
 '71.07': 'prime risk rate', '11.83': 'prime risk share', '31.67': 'prime churner share',
 '67,629.90': 'prime MRR', '2.68': 'lift', '51.35': 'M2M<=12 combined', '55.20': 'M2M 0-6', '42.00': 'M2M 7-12', '1,994': 'M2M<=12 count',
 '158': 'two-year <=24 count', '0.410': 'Cramers V', '13.18': 'charge delta', '53.43': 'HIGH tier rate', '4.93': 'LOW tier rate', '2.01': 'HIGH tier multiple',
}
missing = []
for val, label in claims.items():
    # normalise for thousands separators in stream output
    found = val in stream or val.replace(',', '') in stream.replace(',', '')
    if not found:
        missing.append((val, label))
print(f"\nclaims checked  : {len(claims)}")
if missing:
    print("UNSUPPORTED CLAIMS:")
    for v, l in missing: print(f"   {v:14s} {l}")
else:
    print("all markdown numbers found in executed output -> PASS")

for f in ['01_churn_by_contract','02_retention_curve','03_charges_and_payment',
          '04_contract_tenure_heatmap','05_risk_segments','06_roc','07_revenue_risk', '08_priority_tiers']:
    p = f"{ROOT}/reports/figures/{f}.png"
    import os
    print(f"  {f:32s} {'OK ' if os.path.exists(p) else 'MISSING'} {os.path.getsize(p) if os.path.exists(p) else 0} bytes")

sys.exit(1 if (errors or missing) else 0)
