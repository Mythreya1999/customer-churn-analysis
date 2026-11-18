# 01_data_exploration.sql


## BQ0a. What is in the table? Row/column counts and the grain check.

|   rows |   distinct_customers |   duplicate_ids |   min_tenure |   max_tenure |   min_monthly |   max_monthly |   min_total | max_total   |
|-------:|---------------------:|----------------:|-------------:|-------------:|--------------:|--------------:|------------:|:------------|
|   7043 |                 7043 |               0 |            0 |           72 |         18.25 |        118.75 |           0 | 8,684.80    |


## BQ0b. Which columns can be trusted? Null count per column, via a CTE so the check is written once and the columns are listed explicitly.

| column_name     |   nulls |
|:----------------|--------:|
| Churn           |       0 |
| Contract        |       0 |
| Dependents      |       0 |
| InternetService |       0 |
| MonthlyCharges  |       0 |
| Partner         |       0 |
| PaymentMethod   |       0 |
| SeniorCitizen   |       0 |
| TechSupport     |       0 |
| TotalCharges    |       0 |
| customerID      |       0 |
| gender          |       0 |
| tenure          |       0 |


## BQ0c. What do the categorical columns actually contain? Cardinality first, so an unexpected extra level shows up before it distorts a rate.

| column_name      | level                     |   customers |
|:-----------------|:--------------------------|------------:|
| Contract         | Month-to-month            |        3875 |
| Contract         | Two year                  |        1695 |
| Contract         | One year                  |        1473 |
| Dependents       | No                        |        4933 |
| Dependents       | Yes                       |        2110 |
| InternetService  | Fiber optic               |        3096 |
| InternetService  | DSL                       |        2421 |
| InternetService  | No                        |        1526 |
| PaperlessBilling | Yes                       |        4171 |
| PaperlessBilling | No                        |        2872 |
| Partner          | No                        |        3641 |
| Partner          | Yes                       |        3402 |
| PaymentMethod    | Electronic check          |        2365 |
| PaymentMethod    | Mailed check              |        1612 |
| PaymentMethod    | Bank transfer (automatic) |        1544 |
| PaymentMethod    | Credit card (automatic)   |        1522 |
| SeniorCitizen    | 0                         |        5901 |
| SeniorCitizen    | 1                         |        1142 |
| TechSupport      | No                        |        3473 |
| TechSupport      | Yes                       |        2044 |
| TechSupport      | No internet service       |        1526 |
| gender           | Male                      |        3555 |
| gender           | Female                    |        3488 |


## BQ0d. Are there impossible combinations? A CTE that should return zero rows.

| rule                                |   violations |
|:------------------------------------|-------------:|
| tenure out of 0-72                  |            0 |
| negative monthly charge             |            0 |
| negative total charges              |            0 |
| churn value not 0/1                 |            0 |
| no internet but has online security |            0 |
| no internet but has streaming       |            0 |
| no phone but has multiple lines     |            0 |


## BQ0e. Distribution of the numeric columns - existence of the range, not a chart.

| metric          | mean     |   min | max      |
|:----------------|:---------|------:|:---------|
| tenure_months   | 32.37    |  0    | 72.00    |
| monthly_charges | 64.76    | 18.25 | 118.75   |
| total_charges   | 2,279.73 |  0    | 8,684.80 |


## INTEGRITY GATE Every row must read PASS. If a view drifts, this fails loudly here rather than letting three artifacts disagree later.

| check_name                       |   actual |   expected |
|:---------------------------------|---------:|-----------:|
| gate_1_row_count                 |     7043 |       7043 |
| gate_2_churners                  |     1869 |       1869 |
| gate_3_no_duplicate_ids          |        0 |          0 |
| gate_4_no_null_churn_flag        |        0 |          0 |
| gate_5_no_null_totalcharges      |        0 |          0 |
| gate_6_tenure_bands_sum_to_total |     7043 |       7043 |
| gate_7_charge_bands_sum_to_total |     7043 |       7043 |
| gate_8_risk_points_in_range      |        0 |          0 |
| gate_9_prime_risk_exact          |      833 |        833 |
| gate_10_mrr_reconciles           |   456117 |     456117 |

- `gate_1_row_count`: actual=`7043` expected=`7043` -> **PASS**

- `gate_2_churners`: actual=`1869` expected=`1869` -> **PASS**

- `gate_3_no_duplicate_ids`: actual=`0` expected=`0` -> **PASS**

- `gate_4_no_null_churn_flag`: actual=`0` expected=`0` -> **PASS**

- `gate_5_no_null_totalcharges`: actual=`0` expected=`0` -> **PASS**

- `gate_6_tenure_bands_sum_to_total`: actual=`7043` expected=`7043` -> **PASS**

- `gate_7_charge_bands_sum_to_total`: actual=`7043` expected=`7043` -> **PASS**

- `gate_8_risk_points_in_range`: actual=`0` expected=`0` -> **PASS**

- `gate_9_prime_risk_exact`: actual=`833` expected=`833` -> **PASS**

- `gate_10_mrr_reconciles`: actual=`456116.6` expected=`456116.6` -> **PASS**
