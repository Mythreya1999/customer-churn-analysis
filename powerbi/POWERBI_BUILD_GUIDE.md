# Power BI Build Guide — Customer Churn Analysis & Retention Insights

## What this kit is, and what it is not

A `.pbix` file is a proprietary binary container that **cannot be scripted or generated from text**.
This kit ships the two things that are actually portable, plus the numbers to verify them:

| Artifact | What it is |
|---|---|
| `model/*.csv` | a star schema at importable grain — load these |
| `dax_measures.dax` | 30 measures, grouped by display folder, with expected values in comments |
| this guide | model wiring, the 3 page layouts, and a verification table |
| `customer_churn_dashboard.html` | a **rendered equivalent** of the intended report — interactive, offline |

The HTML file is not the `.pbix` and does not pretend to be one. It exists so the analysis can be
reviewed without a Power BI licence, and it is what the three screenshots were taken from.

---

## 1. Import

1. **Get Data → Text/CSV**, import all five files from `model/`.
2. In Power Query, set these types explicitly (Power BI will otherwise infer text):

| Table | Column | Type |
|---|---|---|
| `fact_churn` | `TenureMonths`, `IsChurned`, `IsPrimeRisk`, `RiskPoints`, `AddOnServices` | Whole Number |
| `fact_churn` | `MonthlyCharges`, `TotalCharges`, `ChurnProbability` | Decimal Number |
| `fact_churn` | `Contract`, `PaymentMethod`, `InternetService`, `TechSupport`, `TenureBand`, `ChargeBand`, `PriorityTier`, `ModelRiskTier` | Text |
| `dim_tenure` | `TenureOrder` | Whole Number |
| `dim_customer` | `SeniorCitizen` | Whole Number |

3. **Do not** let Power BI create a date table — there is no date column anywhere in this data.
   Auto date/time will add six empty hidden tables and confuse the model.

---

## 2. Model

```
          dim_customer (1) ──┐
          dim_tenure   (1) ──┼── (*) fact_churn
                             └──
```

Relationships: single direction, one-to-many, dimension → fact.

| From | To | Column |
|---|---|---|
| `dim_customer[CustomerID]` | `fact_churn[CustomerID]` | 1:* |
| `dim_tenure[TenureBand]` | `fact_churn[TenureBand]` | 1:* |

> **On `dim_contract` / `dim_service`:** these CSVs are keyed on their own surrogate keys, while
> `fact_churn` carries the **attribute values**. Two clean options: merge the key onto the fact in
> Power Query on the natural key, or skip those dimensions entirely — the fact table is already at
> customer grain, so the attributes are correct without them. **The second option cannot go wrong.**

**Sort-by-column:** set `fact_churn[TenureBand]` to sort by `dim_tenure[TenureOrder]`, and add an order
column for `ChargeBand` (`<30`=1 … `90+`=5). Alphabetical band order is the most common way this chart
ships wrong.

---

## 3. Measures

Create a measure table (`Modeling → New table` → `Measures = {BLANK()}`), then paste every measure from
`dax_measures.dax`. Folders: **01 Base, 02 Revenue, 03 Tenure, 04 Segments, 05 Comparison, 06 Data quality**.

---

## 4. Page layouts

Order every page **conclusion → number → visual → detail**. Do not open with filters.

### Page 1 — Executive Overview

| Zone | Content |
|---|---|
| KPI row | `Customers` · `Churned Customers` · `Churn Rate %` · `Retention Rate %` · `MRR` · `MRR Lost` |
| Main | Line-and-column: `Churn Rate %` and cumulative share by `TenureBand` |
| Row 2 | Clustered bar by `Contract` · Bar by demographic segment |
| Row 3 | Bar by `InternetService` and `TechSupport` |

**Do not add a "Churn Trend" line chart.** There is no date column; a monthly trend cannot be computed.
Title the tenure chart *"Churn by tenure — the only time-shaped axis in this snapshot"*.

### Page 2 — Churn Drivers

| Zone | Content |
|---|---|
| Top | Table of attribute strength (Cramér's V) — or replicate with a simple score column; contract 0.410 → gender 0.009 |
| Grid | Contract · Tenure · MonthlyCharges · PaymentMethod · TechSupport · AddOnServices |
| Slicers | Gender · Contract · TenureBand · PaymentMethod · InternetService (+ TechSupport) |

### Page 3 — Customer Retention

| Zone | Content |
|---|---|
| Top | Three cards, one per `PriorityTier`, showing `Churn Rate %`, `Customers`, `MRR Lost` |
| Table | Tier · Customers · Churn rate · MRR lost · ARR exposure · Recommended action · Owner · Success metric |
| Row 2 | `Churn Rate %` by `PriorityTier` · `MRR Lost` by tier · Pareto of cumulative churners by `RiskPoints` |

Copy the action text from `sql/04_retention_insights.sql` BQ20 so the wording matches the SQL.

---

## 5. Verification — values to check after wiring

Blank card per measure, no slicers applied:

| Measure | Expected |
|---|---|
| `Customers` | **7,043** |
| `Churned Customers` | **1,869** |
| `Churn Rate %` | **26.54%** |
| `Retention Rate %` | **73.46%** |
| `MRR` | **$456,116.60** |
| `MRR Lost` | **$139,130.85** |
| `MRR at Risk %` | **30.50%** |
| `ARR Exposure` | **$1,669,570.20** |
| `Avg Monthly Charge (Churners)` | **$74.44** |
| `Charge Delta` | **$13.18** |
| `Avg Tenure (months)` | **32.37** |
| `Avg Tenure (Churners)` | **17.98** |
| `Share of Churn Within 12 Months` | **55.48%** |
| `Month-to-Month Churn Rate` | **42.71%** |
| `Two-Year Churn Rate` | **2.83%** |
| `Electronic Check Churn Rate` | **45.29%** |
| `Prime Risk Customers` / `Prime Risk Churn Rate` | **833** / **71.07%** |
| `High Risk Customers` | **1,559** |
| `Customers with Churn Flag` | **7,043** (= `Customers`) |
| `Tenure Bands Present` | **7** |

Tier verification (page 3), unfiltered:

| Tier | Customers | Churn rate | MRR lost |
|---|---|---|---|
| HIGH (RiskPoints ≥ 8) | 2,684 | 53.43% | $110,507.10 |
| MEDIUM (5–7) | 1,480 | 19.80% | $18,084.15 |
| LOW (≤ 4) | 2,879 | 4.93% | $10,539.60 |

Then prove the slicers are live rather than decorative:

> `Contract = Month-to-month` **and** `TenureBand = 0-6` → expect `Customers` = **1,413**,
> `Churned Customers` = **780**, `Churn Rate %` = **55.20%**.

If a value differs, check band sort order and the `TotalCharges` type first — those two account for
almost every mismatch.

---

## 6. Known differences from the HTML dashboard

| Item | HTML dashboard | Power BI model |
|---|---|---|
| Driver strength | Cramér's V computed live per selection | needs a DAX measure or a precomputed table |
| Pareto cutoff | computed in-page from `RiskPoints` then charge | needs a running-total measure over a ranked table |
| Prime-risk MRR | reports revenue **already lost** ($48,489.95) | `CALCULATE([MRR], IsPrimeRisk=1, IsChurned=1)`; the SQL `mrr` column is segment **total** ($67,629.90) — label whichever you use |
| Tiers | `RiskPoints` scorecard | same column; do not substitute `ModelRiskTier`, it ranks differently |
