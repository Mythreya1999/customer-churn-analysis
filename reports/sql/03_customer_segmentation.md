# 03_customer_segmentation.sql


## 03_customer_segmentation.sql Stage 3: who the churners are - demographics, service bundles, spend deciles, and multi-dimension segment cells ranked by risk.

| attribute      | segment    |   customers |   churners |   churn_rate_pct |
|:---------------|:-----------|------------:|-----------:|-----------------:|
| Dependents     | No         |        4933 |       1543 |            31.28 |
| Dependents     | Yes        |        2110 |        326 |            15.45 |
| Gender         | Female     |        3488 |        939 |            26.92 |
| Gender         | Male       |        3555 |        930 |            26.16 |
| Partner        | No         |        3641 |       1200 |            32.96 |
| Partner        | Yes        |        3402 |        669 |            19.66 |
| Senior citizen | Senior     |        1142 |        476 |            41.68 |
| Senior citizen | Non-senior |        5901 |       1393 |            23.61 |


## BQ10. Family structure combined: does a household anchor retention?

| household                    |   customers |   churners |   churn_rate_pct |   avg_monthly_charges |
|:-----------------------------|------------:|-----------:|-----------------:|----------------------:|
| No partner / No dependents   |        3280 |       1123 |            34.24 |                 62.98 |
| Yes partner / No dependents  |        1653 |        420 |            25.41 |                 74.98 |
| No partner / Yes dependents  |         361 |         77 |            21.33 |                 52.51 |
| Yes partner / Yes dependents |        1749 |        249 |            14.24 |                 60.97 |


## BQ11. Service bundle depth: does holding more add-ons retain customers? n_addon_services is computed in the view layer with a CASE sum, so the definition cannot drift between this query and the dashboard.

|   n_addon_services |   customers |   churners |   churn_rate_pct |   avg_monthly_charges |   avg_tenure_months |   risk_rank |
|-------------------:|------------:|-----------:|-----------------:|----------------------:|--------------------:|------------:|
|                  0 |        1667 |        346 |            20.76 |                 29.75 |                20.7 |           6 |
|                  1 |        1158 |        399 |            34.46 |                 50.79 |                23.2 |           2 |
|                  2 |         957 |        361 |            37.72 |                 68.52 |                23   |           1 |
|                  3 |         978 |        306 |            31.29 |                 76.14 |                31.1 |           3 |
|                  4 |         933 |        240 |            25.72 |                 84.86 |                41.5 |           4 |
|                  5 |         722 |        157 |            21.75 |                 91.2  |                50.3 |           5 |
|                  6 |         420 |         49 |            11.67 |                 97.37 |                60.2 |           7 |
|                  7 |         208 |         11 |             5.29 |                104.63 |                66.3 |           8 |


## BQ12. Spend deciles via NTILE. Answers "is churn concentrated at the top of the bill?" without imposing arbitrary bands - the deciles come from the data.

|   spend_decile |   customers |   churners |   churn_rate_pct |   decile_min_charge |   decile_max_charge |
|---------------:|------------:|-----------:|-----------------:|--------------------:|--------------------:|
|              1 |         705 |         61 |             8.65 |               18.25 |               20.05 |
|              2 |         705 |         66 |             9.36 |               20.05 |               25.05 |
|              3 |         705 |        180 |            25.53 |               25.05 |               45.85 |
|              4 |         704 |        172 |            24.43 |               45.9  |               58.85 |
|              5 |         704 |        153 |            21.73 |               58.9  |               70.35 |
|              6 |         704 |        267 |            37.93 |               70.35 |               79.1  |
|              7 |         704 |        267 |            37.93 |               79.1  |               85.5  |
|              8 |         704 |        241 |            34.23 |               85.5  |               94.25 |
|              9 |         704 |        288 |            40.91 |               94.3  |              102.6  |
|             10 |         704 |        174 |            24.72 |              102.65 |              118.75 |


## BQ13. Ranked segment cells (contract x tenure x payment), with a minimum-size filter so a 3-customer cell with 100% churn cannot top the table. HAVING is the filter that makes the ranking trustworthy.

| segment_cell                                       |   customers |   churners |   churn_rate_pct | mrr_lost   |   risk_rank |
|:---------------------------------------------------|------------:|-----------:|-----------------:|:-----------|------------:|
| Month-to-month | 0-6 | Electronic check            |         680 |        460 |            67.65 | 32,313.25  |           1 |
| Month-to-month | 0-6 | Bank transfer (automatic)   |         110 |         63 |            57.27 | 4,061.40   |           2 |
| Month-to-month | 7-12 | Electronic check           |         274 |        142 |            51.82 | 11,389.90  |           3 |
| Month-to-month | 13-24 | Electronic check          |         355 |        182 |            51.27 | 14,842.40  |           4 |
| Month-to-month | 0-6 | Credit card (automatic)     |         119 |         53 |            44.54 | 3,466.00   |           5 |
| Month-to-month | 25-36 | Electronic check          |         227 |         96 |            42.29 | 8,501.40   |           6 |
| Month-to-month | 0-6 | Mailed check                |         504 |        204 |            40.48 | 9,840.65   |           7 |
| Month-to-month | 37-48 | Electronic check          |         149 |         58 |            38.93 | 5,169.70   |           8 |
| Month-to-month | 7-12 | Bank transfer (automatic)  |          98 |         38 |            38.78 | 3,037.50   |           9 |
| Month-to-month | 49-60 | Electronic check          |         116 |         43 |            37.07 | 3,773.65   |          10 |
| Month-to-month | 7-12 | Credit card (automatic)    |          72 |         26 |            36.11 | 1,913.50   |          11 |
| Month-to-month | 37-48 | Bank transfer (automatic) |          75 |         27 |            36    | 2,377.75   |          12 |
| Month-to-month | 13-24 | Credit card (automatic)   |         121 |         38 |            31.4  | 2,940.90   |          13 |
| Month-to-month | 25-36 | Credit card (automatic)   |          93 |         27 |            29.03 | 2,184.45   |          14 |
| Month-to-month | 7-12 | Mailed check               |         137 |         38 |            27.74 | 2,279.25   |          15 |


## BQ14. Same cells, largest revenue exposure rather than highest rate. The two rankings disagree, which is the point: rate finds the sick cell, revenue finds the expensive one.

| segment_cell           |   customers |   churn_rate_pct | mrr_lost   | arr_exposure   |   revenue_rank |   rate_rank |
|:-----------------------|------------:|-----------------:|:-----------|:---------------|---------------:|------------:|
| Month-to-month | 0-6   |        1413 |            55.2  | 49,681.30  | 596,175.60     |              1 |           1 |
| Month-to-month | 13-24 |         737 |            37.72 | 21,980.30  | 263,763.60     |              2 |           3 |
| Month-to-month | 7-12  |         581 |            42    | 18,620.15  | 223,441.80     |              3 |           2 |
| Month-to-month | 25-36 |         486 |            32.51 | 13,416.95  | 161,003.40     |              4 |           5 |
| Month-to-month | 37-48 |         316 |            33.54 | 9,140.05   | 109,680.60     |              5 |           4 |
| Month-to-month | 49-60 |         234 |            27.78 | 5,684.45   | 68,213.40      |              6 |           6 |
| One year | 49-60       |         321 |            13.71 | 4,034.40   | 48,412.80      |              7 |           8 |
| One year | 61-72       |         313 |            12.14 | 3,808.55   | 45,702.60      |              8 |          10 |
| Two year | 61-72       |         986 |             3.14 | 2,918.10   | 35,017.20      |              9 |          15 |
| One year | 37-48       |         268 |            13.06 | 2,819.60   | 33,835.20      |             10 |           9 |
| Month-to-month | 61-72 |         108 |            22.22 | 2,323.90   | 27,886.80      |             11 |           7 |
| One year | 25-36       |         250 |             8    | 1,701.75   | 20,421.00      |             12 |          13 |
| One year | 13-24       |         197 |             8.12 | 1,101.35   | 13,216.20      |             13 |          12 |
| Two year | 49-60       |         277 |             3.97 | 863.05     | 10,356.60      |             14 |          14 |
| One year | 7-12        |          85 |            10.59 | 438.00     | 5,256.00       |             15 |          11 |


## BQ15. The prime-risk cell, stated as a single decidable definition, plus the nested segments that show how each condition changes the rate.

| segment                              |   customers |   churners |   churn_rate_pct |   pct_of_all_churners |   pct_of_base |   lift | segment_mrr   | mrr_lost   |
|:-------------------------------------|------------:|-----------:|-----------------:|----------------------:|--------------:|-------:|:--------------|:-----------|
| A. Month-to-month & tenure <= 12     |        1994 |       1024 |            51.35 |                 54.79 |         28.31 |   1.94 | 116,086.50    | 68,301.45  |
| B. + Fiber optic                     |         916 |        643 |            70.2  |                 34.4  |         13.01 |   2.65 | 75,183.15     | 53,178.30  |
| C. + no tech support  (prime risk)   |         833 |        592 |            71.07 |                 31.67 |         11.83 |   2.68 | 67,629.90     | 48,489.95  |
| D. Month-to-month & electronic check |        1850 |        994 |            53.73 |                 53.18 |         26.27 |   2.02 | 138,730.55    | 77,315.60  |
| E. Two year & tenure > 24  (safest)  |        1537 |         48 |             3.12 |                  2.57 |         21.82 |   0.12 | 97,993.90     | 4,165.30   |
