# DATA AUDIT — `customer_churn_synthetic.csv`

**Verdict: this file cannot support the project it was downloaded for.** It is not the Telco
customer-churn dataset. It is a 1,000-row synthetic *bank* churn table whose target column is
**reproducible exactly** from three of its own inputs — so any model or "driver" analysis on it
measures the generator, not customer behaviour. Three of the four analyses your brief asks for are
impossible (the columns do not exist), and the fourth (churn rate) is 1.7%, not the 26.5% your
brief quotes.

Audited: 2026-11-18 · 1 file · 1,000 rows × 10 columns · 0 issues in structure, 1 fatal issue in substance.

---

## 1. Inventory

| Property | Value |
|---|---|
| File | `customer_churn_synthetic.csv` (41.7 KB) |
| Rows | 1,000 |
| Columns | 10 |
| Missing values | **0** across all columns |
| Duplicate rows | 0 |
| Primary key | `CustomerID` — unique, 1…1000, no gaps |
| Date columns | none (no time dimension at all) |
| Provenance | filename declares **synthetic**; statistics confirm it (see §4) |

Columns present:

| Column | Type | Range | Notes |
|---|---|---|---|
| CustomerID | int | 1–1000 | surrogate key |
| Age | int | 18–69 | uniform, capped at 69 |
| Gender | object | Male 524 / Female 476 | |
| Tenure_Months | int | 1–71 | uniform, capped ~6 years |
| Balance | float | 9.42–49,985.69 | uniform; **zero accounts: 0** |
| NumOfProducts | int | 1–4 | ~equal quartiles |
| HasCrCard | int | 0/1 | 493 / 507 |
| IsActiveMember | int | 0/1 | exactly 500 / 500 |
| EstimatedSalary | float | 20,121–149,677 | uniform |
| **Churn** | int | 0/1 | **17 churners = 1.70%** |

---

## 2. Integrity — clean, and that is the problem

| Check | Result |
|---|---|
| Nulls | 0 / 10,000 cells |
| Duplicate `CustomerID` | 0 |
| Duplicate full rows | 0 |
| Age < 18 or > 100 | 0 |
| Tenure < 0 or > 120 months | 0 |
| Tenure exceeds customer age | 0 |
| Negative balance | 0 |
| `NumOfProducts` outside 1–4 | 0 |
| Flags outside {0,1} | 0 |
| Constant columns | none |

Structurally this is the cleanest file you will ever audit. There is nothing to clean. Every defect
below is semantic.

---

## 3. Fatal trap: `Churn` is a deterministic function of three inputs

Every one of the 17 churners satisfies the same three conditions, and **nothing else in the file
does**:

```
Churn = 1  ⟺  IsActiveMember == 0  AND  Tenure_Months ≤ 11  AND  Balance ≤ 10,000
```

| Test | Population matched | Churners captured | Purity |
|---|---|---|---|
| `IsActiveMember = 0` | 500 | 17 / 17 (100%) | 3.4% |
| `Tenure_Months ≤ 11` | 161 | 17 / 17 (100%) | 10.6% |
| `Balance ≤ 10,000` | 198 | 17 / 17 (100%) | 8.6% |
| `IsActiveMember = 0` **&** `Tenure ≤ 11` | 75 | 17 / 17 (100%) | 22.7% |
| **all three conditions** | **17** | **17 / 17 (100%)** | **100.0%** |

The three-way conjunction returns exactly the 17 churners and zero false positives. Corroboration:

| Evidence | Value | Interpretation |
|---|---|---|
| Churner `IsActiveMember` values | all 0 | no active member ever churns |
| Churner `Tenure_Months` max | 11 | no churn after month 11 |
| Churner `Balance` max | 9,792.04 | no churner above 10k |
| AUC, `IsActiveMember` + `Tenure` only | 0.9684 | two columns nearly solve the target |
| AUC, all features | 0.9984 | target is effectively leaked |
| Majority-class accuracy | 98.30% | a do-nothing model matches reality |
| Rule accuracy vs actual labels | 94.20% | the rule is tighter than the labels |

**Consequence:** a churn model here reports ~100% AUC and teaches nothing. A "high-risk segment"
here is a hand-written `if` statement, not a finding. If this file is submitted as a portfolio
project, a reviewer who runs three cross-tabs will find the rule in about a minute and the analysis
loses credibility.

---

## 4. Traps 2–5 — the marginals are uniform random draws

| Trap | Evidence | Consequence |
|---|---|---|
| No distributional realism | Age kurtosis −1.14, Balance −1.21, Salary −1.22, Tenure −1.17 (a flat/uniform profile is ≈ −1.2). Real customer data is right-skewed. | Segmentation by quantile produces equal-sized groups by construction. |
| `Balance` never zero | 0 of 1,000 accounts at zero. Real retail-bank churn data (the Kaggle bank dataset this imitates) is ~50% zero-balance. | The single strongest real-world predictor is absent. |
| Feature independence | All pairwise \|r\| between predictors < 0.09 (max 0.074, Age↔Salary). | No confounding to analyse, no interactions, nothing to disentangle. |
| Hard caps | Age max 69, Tenure max 71 months | The dataset contains no long-tenure cohort, so "tenure protects" can only ever be observed inside 0–71 months. |
| Exact 50/50 splits | `IsActiveMember` 500/500, `HasCrCard` 507/493, `NumOfProducts` ≈ 25% each | Balanced-by-construction categoricals; no real skew to explain. |

---

## 5. Statistical power: 17 positives answers almost nothing

With a 1.70% base rate and 1,000 rows, the minimum detectable difference (α = 0.05, power 80%,
n ≈ 500 per group) is **≈ 2.4 percentage points** — i.e. you can only distinguish 1.7% from ≥ 4.1%.

| Split | n | Churners | Rate | Signal? |
|---|---|---|---|---|
| IsActiveMember 0 / 1 | 500 / 500 | 17 / 0 | 3.40% / 0.00% | the only gap that clears the threshold — and it is the generator's rule |
| Gender Female / Male | 476 / 524 | 10 / 7 | 2.10% / 1.34% | noise |
| HasCrCard 0 / 1 | 493 / 507 | 6 / 11 | 1.22% / 2.17% | noise |
| NumOfProducts 1 / 2 / 3 / 4 | 245 / 259 / 262 / 234 | 4 / 2 / 2 / 9 | 1.63 / 0.77 / 0.76 / 3.85% | noise (2–9 positives per cell) |
| Tenure 0–12 / 13+ | 176 / 824 | 17 / 0 | 9.66% / 0.00% | structural, not learned |

Any "segment insight" you write from this table rests on 2–10 individuals. That is not analysis; it
is anecdote with a percentage sign.

---

## 6. The brief vs. the file

Your brief specifies: demographics, subscription tenure, monthly charges, contract type, payment
method, customer-support usage, churn rate, high-risk segments — and quotes **26.5% churn** with
**month-to-month contracts** churning hardest.

| Brief requires | In this file |
|---|---|
| `Contract` (month-to-month / 1yr / 2yr) | ✗ absent |
| `PaymentMethod` | ✗ absent |
| `MonthlyCharges` | ✗ absent |
| `TotalCharges` | ✗ absent |
| Customer-support usage (`TechSupport`, `Complain`, ticket counts) | ✗ absent |
| Tenure | ✓ present (`Tenure_Months`, 1–71) |
| Demographics | ~ partial (Age, Gender only — no SeniorCitizen, Partner, Dependents) |
| Churn rate ≈ 26.5% | ✗ actual **1.70%** |
| Service/telecom attributes | ✗ absent (`InternetService`, `OnlineSecurity`, `StreamingTV` …) |

**0 of 8 named fields exist.** The 26.5% figure in the brief is the published churn rate of the IBM
**Telco Customer Churn** dataset (7,043 rows, 1,869 churners = 26.54%). The file downloaded here is a
different, much smaller, bank-style synthetic table. The brief and the data are for two different
projects.

---

## 7. What this file *can* legitimately support

Not nothing — but only two honest angles:

1. **A data-quality / leakage case study** (genuinely valuable and rare in portfolios): demonstrate
   the audit, prove the target is a deterministic rule, quantify the 1.7% base rate, and explain why
   the "model" is worthless. This is the only angle where the file's defects are the content.
2. **A descriptive profile with no claims about drivers** — the customer base by age / tenure /
   balance / product count, labelled explicitly as a synthetic 1,000-row sample with 17 churners.

Neither matches the brief you wrote, and neither produces the dashboard you sketched (Churn Rate ·
Customer Base · Revenue Risk by Contract / Payment / Charges — five of those six dimensions do not
exist here).

---

## 8. Bottom line

- **Structure: clean (0 defects). Substance: unusable for the stated project (5 traps).**
- The churn column is `IsActiveMember == 0 AND Tenure ≤ 11 AND Balance ≤ 10,000`, reproduced exactly
  — 17/17, 0 false positives. Any model built on it is measuring its own generator.
- The brief's four core dimensions (contract, payment method, monthly charges, support usage) are all
  absent; the quoted 26.5% churn rate does not apply.
- **Recommendation:** use the real Telco Customer Churn dataset the brief was written for (7,043 rows,
  20 columns, 26.54% churn — it contains every field listed in the brief). Keep this file only if you
  want the leakage case study as a separate, deliberately-different showcase.
