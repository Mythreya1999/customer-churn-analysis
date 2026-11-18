# 02_churn_analysis.sql


## 02_churn_analysis.sql Stage 2: how much churn is there, where is it concentrated, and when does it happen. Techniques: aggregation, CASE, CTEs, window functions (RANK, SUM OVER, LAG), and a confidence interval computed in SQL rather than eyeballed. Reads only the governed views created in 01_data_ex

|   customers |   active_customers |   churners |   churn_rate_pct |   retention_rate_pct |   avg_tenure_months |   avg_tenure_churned |   avg_tenure_retained |   avg_monthly_charges |   avg_mc_churned |   avg_mc_retained | mrr_total   | mrr_churned   |
|------------:|-------------------:|-----------:|-----------------:|---------------------:|--------------------:|---------------------:|----------------------:|----------------------:|-----------------:|------------------:|:------------|:--------------|
|        7043 |               5174 |       1869 |            26.54 |                73.46 |               32.37 |                17.98 |                 37.57 |                 64.76 |            74.44 |             61.27 | 456,116.60  | 139,130.85    |


## BQ2. How precise is that 26.54%? Wilson 95% interval, computed in SQL. This SQLite build has no SQRT() (math extension not compiled in), so the square root is solved with a recursive CTE using Newton's method rather than dropping the interval or hard-coding the answer. Judge every segment claim agai

|   churn_rate_pct |   ci_lower_95 |   ci_upper_95 |   ci_width_pp |
|-----------------:|--------------:|--------------:|--------------:|
|            26.54 |         25.52 |         27.58 |          2.06 |


## BQ3. Contract type: the strongest single driver. RANK orders them; the two share columns separate "big segment" from "big problem".

| contract       |   customers |   churners |   churn_rate_pct |   share_of_base_pct |   share_of_churners_pct |   lift | mrr        |   churn_rank |
|:---------------|------------:|-----------:|-----------------:|--------------------:|------------------------:|-------:|:-----------|-------------:|
| Month-to-month |        3875 |       1655 |            42.71 |               55.02 |                   88.55 |   1.61 | 257,294.15 |            1 |
| One year       |        1473 |        166 |            11.27 |               20.91 |                    8.88 |   0.42 | 95,816.60  |            2 |
| Two year       |        1695 |         48 |             2.83 |               24.07 |                    2.57 |   0.11 | 103,005.85 |            3 |


## BQ4. Does tenure protect? An explicit ROWS frame gives the cumulative share of churners; LAG gives the band-over-band drop, which is what "churn falls with tenure" actually asserts.

| tenure_band   |   band_order |   customers |   churners |   churn_rate_pct |   share_of_all_churners_pct |   cumulative_pct_of_churners | change_vs_previous_band_pp   |
|:--------------|-------------:|------------:|-----------:|-----------------:|----------------------------:|-----------------------------:|:-----------------------------|
| 0-6           |            1 |        1481 |        784 |            52.94 |                       41.95 |                        41.95 |                              |
| 7-12          |            2 |         705 |        253 |            35.89 |                       13.54 |                        55.48 | -17.05                       |
| 13-24         |            3 |        1024 |        294 |            28.71 |                       15.73 |                        71.21 | -7.18                        |
| 25-36         |            4 |         832 |        180 |            21.63 |                        9.63 |                        80.85 | -7.08                        |
| 37-48         |            5 |         762 |        145 |            19.03 |                        7.76 |                        88.6  | -2.61                        |
| 49-60         |            6 |         832 |        120 |            14.42 |                        6.42 |                        95.02 | -4.61                        |
| 61-72         |            7 |        1407 |         93 |             6.61 |                        4.98 |                       100    | -7.81                        |


## BQ5. Do higher monthly charges drive churn? Univariate - and confounded with product mix (fiber costs more AND churns more). Reported, not concluded.

| charge_band   |   customers |   churners |   churn_rate_pct |   avg_monthly_charges | mrr        |
|:--------------|------------:|-----------:|-----------------:|----------------------:|:-----------|
| <30           |        1653 |        162 |             9.8  |                 21.5  | 35,545.35  |
| 30-49         |         641 |        199 |            31.05 |                 42.74 | 27,394.75  |
| 50-69         |        1158 |        234 |            20.21 |                 59.86 | 69,314.20  |
| 70-89         |        1847 |        701 |            37.95 |                 79.99 | 147,740.80 |
| 90+           |        1744 |        573 |            32.86 |                100.99 | 176,121.50 |


## BQ6. Payment method: the instrument or the payment mode?

| payment_method            | payment_mode   |   customers |   churners |   churn_rate_pct |   lift |
|:--------------------------|:---------------|------------:|-----------:|-----------------:|-------:|
| Electronic check          | Manual         |        2365 |       1071 |            45.29 |   1.71 |
| Mailed check              | Manual         |        1612 |        308 |            19.11 |   0.72 |
| Bank transfer (automatic) | Automatic      |        1544 |        258 |            16.71 |   0.63 |
| Credit card (automatic)   | Automatic      |        1522 |        232 |            15.24 |   0.57 |


## BQ7. Services: internet type, support level, security, billing paper.

| service           | level               |   customers |   churners |   churn_rate_pct |
|:------------------|:--------------------|------------:|-----------:|-----------------:|
| Device protection | No                  |        3095 |       1211 |            39.13 |
| Device protection | Yes                 |        2422 |        545 |            22.5  |
| Device protection | No internet service |        1526 |        113 |             7.4  |
| Internet service  | Fiber optic         |        3096 |       1297 |            41.89 |
| Internet service  | DSL                 |        2421 |        459 |            18.96 |
| Internet service  | No                  |        1526 |        113 |             7.4  |
| Online backup     | No                  |        3088 |       1233 |            39.93 |
| Online backup     | Yes                 |        2429 |        523 |            21.53 |
| Online backup     | No internet service |        1526 |        113 |             7.4  |
| Online security   | No                  |        3498 |       1461 |            41.77 |
| Online security   | Yes                 |        2019 |        295 |            14.61 |
| Online security   | No internet service |        1526 |        113 |             7.4  |
| Paperless billing | Yes                 |        4171 |       1400 |            33.57 |
| Paperless billing | No                  |        2872 |        469 |            16.33 |
| Tech support      | No                  |        3473 |       1446 |            41.64 |
| Tech support      | Yes                 |        2044 |        310 |            15.17 |
| Tech support      | No internet service |        1526 |        113 |             7.4  |


## BQ8. Where two strong drivers intersect. Two-year contracts show 0.00% churn through month 24 - a structural fact, not a rounding artefact.

| contract       | tenure_band   |   customers |   churners |   churn_rate_pct |
|:---------------|:--------------|------------:|-----------:|-----------------:|
| Month-to-month | 0-6           |        1413 |        780 |            55.2  |
| Month-to-month | 7-12          |         581 |        244 |            42    |
| Month-to-month | 13-24         |         737 |        278 |            37.72 |
| Month-to-month | 25-36         |         486 |        158 |            32.51 |
| Month-to-month | 37-48         |         316 |        106 |            33.54 |
| Month-to-month | 49-60         |         234 |         65 |            27.78 |
| Month-to-month | 61-72         |         108 |         24 |            22.22 |
| One year       | 0-6           |          39 |          4 |            10.26 |
| One year       | 7-12          |          85 |          9 |            10.59 |
| One year       | 13-24         |         197 |         16 |             8.12 |
| One year       | 25-36         |         250 |         20 |             8    |
| One year       | 37-48         |         268 |         35 |            13.06 |
| One year       | 49-60         |         321 |         44 |            13.71 |
| One year       | 61-72         |         313 |         38 |            12.14 |
| Two year       | 0-6           |          29 |          0 |             0    |
| Two year       | 7-12          |          39 |          0 |             0    |
| Two year       | 13-24         |          90 |          0 |             0    |
| Two year       | 25-36         |          96 |          2 |             2.08 |
| Two year       | 37-48         |         178 |          4 |             2.25 |
| Two year       | 49-60         |         277 |         11 |             3.97 |
| Two year       | 61-72         |         986 |         31 |             3.14 |
