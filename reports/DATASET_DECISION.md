# DATASET DECISION — why this project does not use the original download

The brief arrived with `customer_churn_synthetic.csv` (1,000 rows). This project is built on the
**IBM Telco Customer Churn** dataset instead. This file records why, with the evidence.

Full audit of the original file: [`reports/ORIGINAL_FILE_AUDIT.md`](ORIGINAL_FILE_AUDIT.md).

---

## 1. The original file is not the dataset the brief describes

| Brief requires | In `customer_churn_synthetic.csv` |
|---|---|
| `Contract` (month-to-month / 1yr / 2yr) | absent |
| `PaymentMethod` | absent |
| `MonthlyCharges` | absent |
| `TotalCharges` | absent |
| Customer-support usage | absent |
| Churn rate ≈ 26.5% | **1.70%** (17 churners of 1,000) |
| Tenure | present (`Tenure_Months`, 1-71) |
| Demographics | partial (Age, Gender only) |

**0 of 8 named fields exist.** The file is a bank-churn-style table (`Balance`, `NumOfProducts`,
`HasCrCard`, `IsActiveMember`, `EstimatedSalary`). The 26.5% figure in the brief is the published
churn rate of the Telco dataset (1,869 / 7,043 = 26.54%).

---

## 2. The original file's target is a deterministic rule, not a behaviour

Every one of the 17 churners satisfies the same three conditions, and nothing else in the file does:

```
Churn = 1  ⟺  IsActiveMember == 0  AND  Tenure_Months ≤ 11  AND  Balance ≤ 10,000
```

That conjunction returns **17 of 17 churners with 0 false positives**. AUC using only
`IsActiveMember` and `Tenure` is 0.968; with all features, 0.998.

Any model, lift chart or "driver" analysis built on that column measures the generator. A reviewer
running three cross-tabs finds the rule.

---

## 3. Statistical power: 17 positives answers almost nothing

With a 1.70% base rate and 1,000 rows, the minimum detectable difference (α = 0.05, power 80%,
n ≈ 500 per group) is ≈ 2.4 percentage points. Every segment besides inactive/active rests on 2-10
individuals.

The marginals are also uniform random draws (Age kurtosis −1.14, Balance −1.21, Salary −1.22;
`IsActiveMember` exactly 500/500; zero accounts with `Balance = 0`, where real retail-bank data is
~50% zero-balance). There is no real distribution to describe.

---

## 4. What was decided

- **Project 2 (this repository)** uses the Telco file, because the brief's questions — contract,
  payment method, monthly charges, support usage, 26.5% churn — only exist there.
- **The original file was not discarded silently.** It was audited, and the audit is kept as a
  separate artifact. Its one genuine portfolio value is as a data-leakage case study: proving a target
  is a deterministic function of its own features is a rarer and more senior demonstration than a
  churn dashboard.

## 5. If the original file is wanted as its own project

The honest angles are:

1. **Leakage / data-quality case study** — audit, rule recovery, why the model is worthless. The
   defects are the content.
2. **Descriptive profile with no driver claims** — labelled explicitly as a 1,000-row synthetic
   sample with 17 churners.

Neither produces the dashboard sketched in the brief, because five of its six dimensions do not exist
in that file.
