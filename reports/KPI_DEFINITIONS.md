# KPI DEFINITIONS

Every number in this project resolves to one of the definitions below. Where a second definition is
legitimate, the gap between them is quantified so the choice is auditable rather than invisible.
Source of truth: `sql/01_data_exploration.sql` (governed view layer + integrity gate).

---

## 1. Base and grain

| Item | Value |
|---|---|
| Grain | 1 row = 1 customer |
| Rows | 7,043 |
| Primary key | `customerID` — unique, 0 duplicates |
| Time dimension | **none** — single snapshot |
| Date range | not applicable |

Because there is no time dimension, **no figure in this project is a trend, a growth rate, or a
seasonal pattern.** Anything that looks like movement over time is movement across a categorical
variable (tenure, contract, charge band).

---

## 2. Churn rate — the primary metric

```
Churn Rate = COUNT(customers where Churn = 'Yes') / COUNT(all customers)
Retention Rate = 1 − Churn Rate
```

| Item | Value |
|---|---|
| Churned | 1,869 |
| Base | 7,043 |
| **Churn rate** | **26.54%** |
| 95% Wilson interval | [25.52%, 27.58%] (computed in SQL via a recursive CTE — `02_churn_analysis.sql` BQ2) |
| Retention rate | 73.46% |

**Legitimate variants and the gap between them:**

| Variant | Value | Gap vs chosen | When it would be right |
|---|---|---|---|
| All customers (**chosen**) | 26.54% | — | The file is a customer census |
| Excluding `tenure = 0` customers | 26.58% | +0.04 pp | If tenure-0 rows are pending activations, not customers |
| Churn among customers with ≥12 months tenure | 17.49% | −9.05 pp | If measuring *established*-customer attrition — a different question |

The first two are interchangeable (0.04 pp). The third is **not** a churn-rate variant; quoting it as
"the churn rate" would understate churn by 9 points. This project uses the census definition everywhere
and reports the ≥12-month figure only as a named, separate statistic.

---

## 3. Revenue definitions

| KPI | Definition | Value |
|---|---|---|
| MRR total | `SUM(MonthlyCharges)` | **$456,116.60** |
| MRR on churned accounts | `SUM(MonthlyCharges)` where churned | **$139,130.85** |
| Share of MRR exposed | MRR churned ÷ MRR total | **30.50%** |
| Annualised exposure | MRR churned × 12 | **$1,669,570.20** |
| Avg monthly charge — churned / retained | | $74.44 / $61.27 |
| Charge delta | churned − retained | **+$13.18 / month** |
| Avg lifetime revenue — churned / retained | `AVG(TotalCharges)` | $1,531.80 / $2,549.91 |

**"Revenue at risk" is a run-rate exposure, not a realised loss.** It assumes a churner would have kept
paying the same amount for 12 more months. It is **not** CLV (no margin, no cost-to-serve, no discount
rate) and **not** forecast revenue. Any claim about money *lost* should say "exposure".

**MRR lost by contract** (the prioritisation table):

| Contract | MRR lost | Annualised |
|---|---|---|
| Month-to-month | $120,847.10 | $1,450,165.20 |
| One year | $14,118.45 | $169,421.40 |
| Two year | $4,165.30 | $49,983.60 |

---

## 4. Segment definitions

Written as SQL flags in `v_customers` so no artifact can redefine them:

| Flag | Definition |
|---|---|
| `is_churned` | `Churn = 'Yes'` |
| `is_new_customer` | `tenure <= 12` |
| `is_month_to_month` | `Contract = 'Month-to-month'` |
| `is_prime_risk_segment` | month-to-month **AND** tenure ≤ 12 **AND** `InternetService = 'Fiber optic'` **AND** `TechSupport = 'No'` |
| `n_addon_services` | count of optional services held (MultipleLines, OnlineSecurity, OnlineBackup, DeviceProtection, TechSupport, StreamingTV, StreamingMovies) — phone excluded (90% penetration) |
| `tenure_band` | 0-6, 7-12, 13-24, 25-36, 37-48, 49-60, 61-72 — **left-closed**: `0-6` means `tenure <= 6` |
| `charge_band` | `<30`, `30-49`, `50-69`, `70-89`, `90+` — **left-closed**: `30-49` means `30 <= x < 50` |

**Band boundary convention is enforced, not assumed.** A right-closed pandas `cut` puts a customer
paying exactly $50.00 into `30-49`; the SQL `CASE` puts them in `50-69`. That convention moved 21
customers between bands and changed two churn rates in the second decimal. The notebook asserts
band-for-band equality against the SQL views.

---

## 5. Risk scorecard and priority tiers

The tiering is a **points scorecard**, defined once in `sql/01_data_exploration.sql` as `risk_points`
and consumed by `04_retention_insights.sql`, the notebook and the dashboard.

| Component | Points |
|---|---|
| Contract = Month-to-month | 3 |
| Tenure ≤ 6 months / ≤ 12 / ≤ 24 | 3 / 2 / 1 |
| InternetService = Fiber optic | 2 |
| TechSupport = No | 2 |
| PaymentMethod = Electronic check | 2 |
| OnlineSecurity = No | 1 |
| SeniorCitizen = 1 | 1 |
| **Range** | **0 – 14** |

**Cut-offs are set where the observed churn rate steps up**, evidenced by BQ16 (churn rate at every
score value: 1.74% at 0 points rising monotonically to 78.26% at 14):

| Tier | Score | Customers | Churn rate | Multiple of base | % of all churners |
|---|---|---|---|---|---|
| HIGH | ≥ 8 | 2,684 | **53.43%** | 2.01x | 76.73% |
| MEDIUM | 5–7 | 1,480 | 19.80% | 0.75x | 15.68% |
| LOW | ≤ 4 | 2,879 | 4.93% | 0.19x | 7.60% |

Two integrity checks run on every build: the tiers must sum to the base (7,043) and to all churners
(1,869), and the rates must be strictly monotone HIGH > MEDIUM > LOW. Both PASS.

**A second, weaker definition exists and is deliberately not mixed with it:** the logistic model's
`risk_tier` (probability bands `<0.25 / 0.5 / 0.75 / 1.0`). It ranks differently because it is
multivariate. Where both appear, they are labelled `PriorityTier` (scorecard) and `ModelRiskTier`
(model) in `fact_churn.csv`.

---

## 6. Model metrics

| Metric | Value | Note |
|---|---|---|
| Algorithm | logistic regression, 30 dummy features | `C = 0.5`, standardised |
| Split | 70/30 stratified, `random_state=42` | |
| AUC train | 0.8487 | |
| **AUC test** | **0.8446** | the number to quote |
| Baseline (always predict retained) | 73.46% accuracy | any accuracy claim must beat this |

**The model is a scoring aid, not an explanation of causation.** `MonthlyCharges` enters with a
negative coefficient (−0.486) although higher charge bands show higher churn, because tenure and
`TotalCharges` are collinear with it. Univariate tables and multivariate coefficients must not be read
as agreeing.

---

## 7. Data cleaning decisions

| Decision | Rule | Rows affected | Rationale |
|---|---|---|---|
| `TotalCharges` blanks | read as `0.00` | 11 | all have `tenure = 0` (never billed); dropping them deletes the newest, highest-risk cohort |
| `Churn` encoding | `Churn = 'Yes'` → `is_churned = 1` | 7,043 | every KPI filters the flag, never the string |
| `"No internet service"` | kept as its own level | 1,526 | a real state, not missing data; folding it into "No" inflates the tech-support churn rate |
| Duplicates | none found | 0 | `customerID` unique |
