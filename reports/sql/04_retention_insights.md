# 04_retention_insights.sql


## 04_retention_insights.sql Stage 4: turn the analysis into a priority list the business can act on. The tiers are NOT asserted - they are derived from an explainable points scorecard whose cut-offs are set where the observed churn rate steps up.

|   risk_points |   customers |   churners |   churn_rate_pct | mrr_lost   |
|--------------:|------------:|-----------:|-----------------:|:-----------|
|             0 |        1091 |         19 |             1.74 | 1,040.40   |
|             1 |         411 |         16 |             3.89 | 1,055.05   |
|             2 |         538 |         32 |             5.95 | 2,762.75   |
|             3 |         451 |         31 |             6.87 | 2,260.90   |
|             4 |         388 |         44 |            11.34 | 3,420.50   |
|             5 |         461 |         67 |            14.53 | 4,979.70   |
|             6 |         634 |        139 |            21.92 | 6,656.65   |
|             7 |         385 |         87 |            22.6  | 6,447.80   |
|             8 |         495 |        158 |            31.92 | 11,927.75  |
|             9 |         535 |        235 |            43.93 | 15,963.05  |
|            10 |         409 |        207 |            50.61 | 17,060.90  |
|            11 |         546 |        332 |            60.81 | 25,104.15  |
|            12 |         259 |        162 |            62.55 | 12,799.35  |
|            13 |         325 |        250 |            76.92 | 20,374.05  |
|            14 |         115 |         90 |            78.26 | 7,277.85   |


## BQ17. Priority tiers. Cut-offs: HIGH >= 8 points, MEDIUM 5-7, LOW <= 4. The multiple column is what justifies acting: a tier churning at 3-4x base is a different business decision from one at 0.3x.

| priority_tier   |   customers |   churners |   churn_rate_pct |   pct_of_base |   pct_of_all_churners |   multiple_of_base_rate | mrr_lost   | arr_exposure   |   min_score |   max_score |
|:----------------|------------:|-----------:|-----------------:|--------------:|----------------------:|------------------------:|:-----------|:---------------|------------:|------------:|
| 1. HIGH         |        2684 |       1434 |            53.43 |         38.11 |                 76.73 |                    2.01 | 110,507.10 | 1,326,085.20   |           8 |          14 |
| 2. MEDIUM       |        1480 |        293 |            19.8  |         21.01 |                 15.68 |                    0.75 | 18,084.15  | 217,009.80     |           5 |           7 |
| 3. LOW          |        2879 |        142 |             4.93 |         40.88 |                  7.6  |                    0.19 | 10,539.60  | 126,475.20     |           0 |           4 |


## BQ18. Who is actually in the HIGH tier? A priority list nobody can describe operationally is not a priority list.

| contract       | tenure_bucket   | payment_method            |   customers |   churners |   churn_rate_pct | mrr_lost   |
|:---------------|:----------------|:--------------------------|------------:|-----------:|-----------------:|:-----------|
| Month-to-month | 0-6             | Electronic check          |         680 |        460 |            67.65 | 32,313.25  |
| Month-to-month | 25+             | Electronic check          |         463 |        204 |            44.06 | 18,357.20  |
| Month-to-month | 13-24           | Electronic check          |         319 |        174 |            54.55 | 14,480.35  |
| Month-to-month | 7-12            | Electronic check          |         260 |        139 |            53.46 | 11,265.00  |
| Month-to-month | 0-6             | Mailed check              |         245 |        133 |            54.29 | 8,020.45   |
| Month-to-month | 25+             | Bank transfer (automatic) |         107 |         42 |            39.25 | 3,815.25   |
| Month-to-month | 0-6             | Bank transfer (automatic) |          72 |         52 |            72.22 | 3,716.40   |
| Month-to-month | 0-6             | Credit card (automatic)   |          81 |         46 |            56.79 | 3,194.70   |
| Month-to-month | 25+             | Credit card (automatic)   |          92 |         33 |            35.87 | 2,924.10   |
| Month-to-month | 7-12            | Bank transfer (automatic) |          62 |         32 |            51.61 | 2,664.00   |
| Month-to-month | 13-24           | Credit card (automatic)   |          58 |         27 |            46.55 | 2,321.00   |
| Month-to-month | 13-24           | Bank transfer (automatic) |          63 |         23 |            36.51 | 1,937.05   |


## BQ19. Pareto: how small a slice of the base holds 80% of the churn? Ordered by score, this says how many customers a retention team must touch.

|   customers_needed |   pct_of_base |   pct_of_churn_captured |
|-------------------:|--------------:|------------------------:|
|               2962 |         42.06 |                   80.04 |


## BQ20. The action table: one row per tier, with the intervention and the size of the prize. This is the deliverable a retention manager acts on.

| priority_tier   |   customers |   churners |   churn_rate_pct | mrr_lost   | arr_exposure   | recommended_action                                                                       | owner                   | success_metric                                     |
|:----------------|------------:|-----------:|-----------------:|:-----------|:---------------|:-----------------------------------------------------------------------------------------|:------------------------|:---------------------------------------------------|
| 1. HIGH         |        2684 |       1434 |            53.43 | 110,507.10 | 1,326,085.20   | Personal retention call within 14 days; offer contract upgrade with tech support bundled | Named agent, 30-day SLA | Churn rate and 90-day save rate on the HIGH cohort |
| 2. MEDIUM       |        1480 |        293 |            19.8  | 18,084.15  | 217,009.80     | Automated multi-channel campaign; nudge e-check to automatic payment                     | Marketing automation    | Conversion of e-check to automatic payment         |
| 3. LOW          |        2879 |        142 |             4.93 | 10,539.60  | 126,475.20     | No outreach; loyalty programme and referral only                                         | Self-serve              | Watch for reclassification into MEDIUM             |


## BQ20b. Revenue exposure, as one governed view. Run-rate exposure, NOT realised loss and NOT CLV (no margin, no cost-to-serve in this dataset).

| mrr_lost   | arr_exposure   | mrr_total   | arr_total    |   pct_mrr_exposed |   avg_mc_churner |   avg_mc_retained |   charge_delta |
|:-----------|:---------------|:------------|:-------------|------------------:|-----------------:|------------------:|---------------:|
| 139,130.85 | 1,669,570.20   | 456,116.60  | 5,473,399.20 |              30.5 |            74.44 |             61.27 |          13.18 |


## BQ21. Segment-level revenue exposure, ranked, for budget allocation. Churn rate alone misleads: a small high-rate cell can cost less than a large medium-rate one.

| segment        |   customers |   churners |   churn_rate_pct | mrr_lost   | arr_exposure   |   pct_of_total_exposure |   exposure_rank |
|:---------------|------------:|-----------:|-----------------:|:-----------|:---------------|------------------------:|----------------:|
| Month-to-month |        3875 |       1655 |            42.71 | 120,847.10 | 1,450,165.20   |                   86.86 |               1 |
| One year       |        1473 |        166 |            11.27 | 14,118.45  | 169,421.40     |                   10.15 |               2 |
| Two year       |        1695 |         48 |             2.83 | 4,165.30   | 49,983.60      |                    2.99 |               3 |


## BQ22. Integrity: the tiers must partition the base and stay monotone. A tiering that overlaps or inverts is worse than no tiering.

| check_name                  | actual   | expected   |
|:----------------------------|:---------|:-----------|
| tiers_sum_to_base           | 7043     | 7043       |
| tiers_sum_churners          | 1869     | 1869       |
| high_tier_rate_above_medium | PASS     | PASS       |
| medium_tier_rate_above_low  | PASS     | PASS       |
| high_tier_rate_above_base   | PASS     | PASS       |

- `tiers_sum_to_base`: actual=`7043` expected=`7043` -> **PASS**

- `tiers_sum_churners`: actual=`1869` expected=`1869` -> **PASS**

- `high_tier_rate_above_medium`: actual=`PASS` expected=`PASS` -> **PASS**

- `medium_tier_rate_above_low`: actual=`PASS` expected=`PASS` -> **PASS**

- `high_tier_rate_above_base`: actual=`PASS` expected=`PASS` -> **PASS**
