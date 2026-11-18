"""Export the dashboard payload and the Power BI star-schema kit.

risk_points and the priority tier come from the SQL view v_customers, not from a
re-implementation in Python - so "high risk" has exactly one definition in the project.
"""
import pandas as pd, json, os, sqlite3

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
df = pd.read_csv(f"{ROOT}/data/processed/customer_churn_scored.csv")

# --- the scorecard, read back from the governed SQL view ---
con = sqlite3.connect(f"{ROOT}/db/churn.db")
scored = pd.read_sql_query("SELECT customerID, risk_points, is_prime_risk_segment, n_addon_services FROM v_customers", con)
con.close()
df = df.merge(scored, on='customerID', how='left')
assert df.risk_points.notna().all(), "risk_points missing for some customers"

df['tenure_band'] = pd.cut(df.tenure, [-1, 6, 12, 24, 36, 48, 60, 72],
                           labels=['0-6', '7-12', '13-24', '25-36', '37-48', '49-60', '61-72'])
df['charge_band'] = pd.cut(df.MonthlyCharges, [0, 30, 50, 70, 90, 200],
                           labels=['<30', '30-49', '50-69', '70-89', '90+'], right=False)
df['priority_tier'] = pd.cut(df.risk_points, [-1, 4, 7, 99],
                             labels=['3. LOW', '2. MEDIUM', '1. HIGH'])

# ---------------- dashboard payload ----------------
dims = {
    'contract': ['Month-to-month', 'One year', 'Two year'],
    'gender': ['Female', 'Male'],
    'internet': ['DSL', 'Fiber optic', 'No'],
    'tech': ['No', 'No internet service', 'Yes'],
    'security': ['No', 'No internet service', 'Yes'],
    'payment': ['Bank transfer (automatic)', 'Credit card (automatic)', 'Electronic check', 'Mailed check'],
    'tenure_band': ['0-6', '7-12', '13-24', '25-36', '37-48', '49-60', '61-72'],
    'charge_band': ['<30', '30-49', '50-69', '70-89', '90+'],
    'tier': ['1. HIGH', '2. MEDIUM', '3. LOW'],
}
idx = {k: {v: i for i, v in enumerate(vs)} for k, vs in dims.items()}

rows = []
for r in df.itertuples(index=False):
    rows.append([
        idx['contract'][r.Contract], int(r.tenure), round(float(r.MonthlyCharges), 2),
        round(float(r.TotalCharges), 2), int(r.churn_flag), idx['gender'][r.gender],
        int(r.SeniorCitizen), idx['internet'][r.InternetService], idx['tech'][r.TechSupport],
        idx['security'][r.OnlineSecurity], idx['payment'][r.PaymentMethod],
        idx['tenure_band'][str(r.tenure_band)], idx['charge_band'][str(r.charge_band)],
        int(r.is_prime_risk_segment), int(r.Partner == 'Yes'), int(r.Dependents == 'Yes'),
        int(r.risk_points), idx['tier'][str(r.priority_tier)], int(r.n_addon_services),
    ])

payload = {
    'cols': ['contract', 'tenure', 'monthly', 'total', 'churn', 'gender', 'senior', 'internet',
             'tech', 'security', 'payment', 'tenure_band', 'charge_band', 'prime_risk',
             'partner', 'dependents', 'risk_points', 'tier', 'n_addons'],
    'dims': dims,
    'rows': rows,
    'expected': {'customers': 7043, 'churners': 1869, 'churn_rate': 26.54,
                 'mrr_total': 456116.60, 'mrr_churned': 139130.85},
}
os.makedirs(f"{ROOT}/build", exist_ok=True)
json.dump(payload, open(f"{ROOT}/build/dash_payload.json", 'w'), separators=(',', ':'))
print("payload rows:", len(rows), "| size KB:", round(os.path.getsize(f'{ROOT}/build/dash_payload.json')/1024, 1))

# ---------------- Power BI star schema ----------------
bi = f"{ROOT}/powerbi/model"
os.makedirs(bi, exist_ok=True)

dim_customer = df[['customerID', 'gender', 'SeniorCitizen', 'Partner', 'Dependents']].copy()
dim_customer.columns = ['CustomerID', 'Gender', 'SeniorCitizen', 'Partner', 'Dependents']
dim_customer.to_csv(f"{bi}/dim_customer.csv", index=False)

dim_contract = df[['Contract', 'PaperlessBilling', 'PaymentMethod']].drop_duplicates().reset_index(drop=True)
dim_contract.insert(0, 'ContractKey', range(1, len(dim_contract) + 1))
dim_contract['PaymentMode'] = dim_contract.PaymentMethod.map(lambda x: 'Automatic' if 'automatic' in x else 'Manual')
dim_contract.to_csv(f"{bi}/dim_contract.csv", index=False)

dim_service = (df[['InternetService', 'OnlineSecurity', 'OnlineBackup', 'DeviceProtection',
                   'TechSupport', 'StreamingTV', 'StreamingMovies', 'PhoneService', 'MultipleLines']]
                 .drop_duplicates().reset_index(drop=True))
dim_service.insert(0, 'ServiceKey', range(1, len(dim_service) + 1))
dim_service.to_csv(f"{bi}/dim_service.csv", index=False)

dim_tenure = pd.DataFrame({
    'TenureBand': ['0-6', '7-12', '13-24', '25-36', '37-48', '49-60', '61-72'],
    'TenureOrder': range(1, 8),
})
dim_tenure.to_csv(f"{bi}/dim_tenure.csv", index=False)

fact = df[['customerID', 'Contract', 'PaymentMethod', 'InternetService', 'TechSupport',
           'tenure', 'tenure_band', 'MonthlyCharges', 'charge_band', 'TotalCharges',
           'churn_flag', 'is_prime_risk_segment', 'risk_points', 'priority_tier',
           'n_addon_services', 'p_churn', 'risk_tier']].copy()
fact.columns = ['CustomerID', 'Contract', 'PaymentMethod', 'InternetService', 'TechSupport',
                'TenureMonths', 'TenureBand', 'MonthlyCharges', 'ChargeBand', 'TotalCharges',
                'IsChurned', 'IsPrimeRisk', 'RiskPoints', 'PriorityTier',
                'AddOnServices', 'ChurnProbability', 'ModelRiskTier']
fact['PriorityTier'] = fact.PriorityTier.astype(str)
fact['ModelRiskTier'] = fact.ModelRiskTier.astype(str)
fact.to_csv(f"{bi}/fact_churn.csv", index=False)

print("BI files:")
for f in sorted(os.listdir(bi)):
    d = pd.read_csv(f"{bi}/{f}")
    print(f"  {f:22s} rows={len(d):5d} cols={d.shape[1]}")

v = {
    'customers': int(len(df)), 'churners': int(df.churn_flag.sum()),
    'churn_rate': round(df.churn_flag.mean()*100, 2),
    'mrr_total': round(df.MonthlyCharges.sum(), 2),
    'mrr_churned': round(df.loc[df.churn_flag == 1, 'MonthlyCharges'].sum(), 2),
    'arr_exposure': round(df.loc[df.churn_flag == 1, 'MonthlyCharges'].sum()*12, 2),
    'tier_high': int((df.priority_tier == '1. HIGH').sum()),
    'tier_medium': int((df.priority_tier == '2. MEDIUM').sum()),
    'tier_low': int((df.priority_tier == '3. LOW').sum()),
    'tier_high_rate': round(df[df.priority_tier == '1. HIGH'].churn_flag.mean()*100, 2),
    'tier_medium_rate': round(df[df.priority_tier == '2. MEDIUM'].churn_flag.mean()*100, 2),
    'tier_low_rate': round(df[df.priority_tier == '3. LOW'].churn_flag.mean()*100, 2),
}
json.dump(v, open(f"{ROOT}/build/verification_values.json", 'w'), indent=2)
print("\nverification values:", json.dumps(v, indent=2))
