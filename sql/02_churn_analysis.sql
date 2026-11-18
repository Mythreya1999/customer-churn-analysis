-- ============================================================================
-- 02_churn_analysis.sql
-- Stage 2: how much churn is there, where is it concentrated, and when does it happen.
-- Techniques: aggregation, CASE, CTEs, window functions (RANK, SUM OVER, LAG),
-- and a confidence interval computed in SQL rather than eyeballed.
-- Reads only the governed views created in 01_data_exploration.sql.
-- ============================================================================

-- ---------------------------------------------------------------------------
-- BQ1. Headline customer health: totals, churn/retention rate, tenure, charges.
--      Published as a view so every artifact reads the same numbers.
-- ---------------------------------------------------------------------------
DROP VIEW IF EXISTS v_kpi_overall;
CREATE VIEW v_kpi_overall AS
SELECT
    COUNT(*)                                                     AS customers,
    COUNT(*) - SUM(is_churned)                                   AS active_customers,
    SUM(is_churned)                                              AS churners,
    ROUND(100.0 * SUM(is_churned) / COUNT(*), 2)                  AS churn_rate_pct,
    ROUND(100.0 * (COUNT(*) - SUM(is_churned)) / COUNT(*), 2)     AS retention_rate_pct,
    ROUND(AVG(tenure_months), 2)                                  AS avg_tenure_months,
    ROUND(AVG(CASE WHEN is_churned = 1 THEN tenure_months END), 2) AS avg_tenure_churned,
    ROUND(AVG(CASE WHEN is_churned = 0 THEN tenure_months END), 2) AS avg_tenure_retained,
    ROUND(AVG(monthly_charges), 2)                                AS avg_monthly_charges,
    ROUND(AVG(CASE WHEN is_churned = 1 THEN monthly_charges END), 2) AS avg_mc_churned,
    ROUND(AVG(CASE WHEN is_churned = 0 THEN monthly_charges END), 2) AS avg_mc_retained,
    ROUND(SUM(monthly_charges), 2)                                AS mrr_total,
    ROUND(SUM(CASE WHEN is_churned = 1 THEN monthly_charges ELSE 0 END), 2) AS mrr_churned
FROM v_customers;

SELECT * FROM v_kpi_overall;

-- ---------------------------------------------------------------------------
-- BQ2. How precise is that 26.54%? Wilson 95% interval, computed in SQL.
--      This SQLite build has no SQRT() (math extension not compiled in), so the
--      square root is solved with a recursive CTE using Newton's method rather
--      than dropping the interval or hard-coding the answer.
--      Judge every segment claim against this width before calling it a finding.
-- ---------------------------------------------------------------------------
WITH RECURSIVE
k AS (
    SELECT COUNT(*) AS n, 1.0 * SUM(is_churned) / COUNT(*) AS p, 1.96 AS z
    FROM v_customers
),
var AS (
    -- the quantity under the root in the Wilson half-width
    SELECT n, p, z, (p * (1 - p) / n + z * z / (4.0 * n * n)) AS v
    FROM k
),
newton(g, i, n, p, z, v) AS (
    SELECT 1.0, 1, n, p, z, v          -- seed: an upper bound, since v << 1
    FROM var
    UNION ALL
    SELECT 0.5 * (g + v / g), i + 1, n, p, z, v
    FROM newton
    WHERE i < 40                        -- ~16 halvings then quadratic convergence
),
solved AS (
    SELECT n, p, z, g AS sqrt_v FROM newton ORDER BY i DESC LIMIT 1
)
SELECT
    ROUND(p * 100, 2)                                                            AS churn_rate_pct,
    ROUND(((p + z*z/(2.0*n)) - z*sqrt_v) / (1.0 + z*z/n) * 100, 2)               AS ci_lower_95,
    ROUND(((p + z*z/(2.0*n)) + z*sqrt_v) / (1.0 + z*z/n) * 100, 2)               AS ci_upper_95,
    ROUND((2.0 * z * sqrt_v) / (1.0 + z*z/n) * 100, 2)                            AS ci_width_pp
FROM solved;

-- ---------------------------------------------------------------------------
-- BQ3. Contract type: the strongest single driver. RANK orders them; the two
--      share columns separate "big segment" from "big problem".
-- ---------------------------------------------------------------------------
DROP VIEW IF EXISTS v_churn_by_contract;
CREATE VIEW v_churn_by_contract AS
SELECT
    Contract                                                     AS contract,
    COUNT(*)                                                     AS customers,
    SUM(is_churned)                                              AS churners,
    ROUND(100.0 * SUM(is_churned) / COUNT(*), 2)                  AS churn_rate_pct,
    ROUND(100.0 * COUNT(*) / (SELECT COUNT(*) FROM v_customers), 2)                AS share_of_base_pct,
    ROUND(100.0 * SUM(is_churned) / (SELECT SUM(is_churned) FROM v_customers), 2)  AS share_of_churners_pct,
    ROUND((1.0 * SUM(is_churned) / COUNT(*))
          / ((SELECT 1.0 * SUM(is_churned) / COUNT(*) FROM v_customers)), 2)       AS lift,
    ROUND(SUM(monthly_charges), 2)                                AS mrr,
    RANK() OVER (ORDER BY 1.0 * SUM(is_churned) / COUNT(*) DESC)   AS churn_rank
FROM v_customers
GROUP BY Contract
ORDER BY churn_rank;

SELECT * FROM v_churn_by_contract;

-- ---------------------------------------------------------------------------
-- BQ4. Does tenure protect? An explicit ROWS frame gives the cumulative share of
--      churners; LAG gives the band-over-band drop, which is what "churn falls
--      with tenure" actually asserts.
-- ---------------------------------------------------------------------------
DROP VIEW IF EXISTS v_churn_by_tenure_band;
CREATE VIEW v_churn_by_tenure_band AS
WITH banded AS (
    SELECT
        tenure_band,
        CASE tenure_band
            WHEN '0-6' THEN 1 WHEN '7-12' THEN 2 WHEN '13-24' THEN 3
            WHEN '25-36' THEN 4 WHEN '37-48' THEN 5 WHEN '49-60' THEN 6 ELSE 7
        END                                          AS band_order,
        COUNT(*)                                      AS customers,
        SUM(is_churned)                               AS churners,
        1.0 * SUM(is_churned) / COUNT(*)              AS churn_rate
    FROM v_customers
    GROUP BY tenure_band
)
SELECT
    tenure_band,
    band_order,
    customers,
    churners,
    ROUND(churn_rate * 100, 2)                                        AS churn_rate_pct,
    ROUND(100.0 * churners / (SELECT SUM(is_churned) FROM v_customers), 2) AS share_of_all_churners_pct,
    ROUND(100.0 * SUM(churners) OVER (
        ORDER BY band_order
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) / (SELECT SUM(is_churned) FROM v_customers), 2)                 AS cumulative_pct_of_churners,
    ROUND(100.0 * (churn_rate - LAG(churn_rate) OVER (ORDER BY band_order)), 2) AS change_vs_previous_band_pp
FROM banded
ORDER BY band_order;

SELECT * FROM v_churn_by_tenure_band;

-- ---------------------------------------------------------------------------
-- BQ5. Do higher monthly charges drive churn? Univariate - and confounded with
--      product mix (fiber costs more AND churns more). Reported, not concluded.
-- ---------------------------------------------------------------------------
DROP VIEW IF EXISTS v_churn_by_charge_band;
CREATE VIEW v_churn_by_charge_band AS
SELECT
    charge_band,
    COUNT(*)                                      AS customers,
    SUM(is_churned)                               AS churners,
    ROUND(100.0 * SUM(is_churned) / COUNT(*), 2)  AS churn_rate_pct,
    ROUND(AVG(monthly_charges), 2)                AS avg_monthly_charges,
    ROUND(SUM(monthly_charges), 2)                AS mrr
FROM v_customers
GROUP BY charge_band
ORDER BY CASE charge_band
    WHEN '<30' THEN 1 WHEN '30-49' THEN 2 WHEN '50-69' THEN 3
    WHEN '70-89' THEN 4 ELSE 5 END;

SELECT * FROM v_churn_by_charge_band;

-- ---------------------------------------------------------------------------
-- BQ6. Payment method: the instrument or the payment mode?
-- ---------------------------------------------------------------------------
DROP VIEW IF EXISTS v_churn_by_payment;
CREATE VIEW v_churn_by_payment AS
SELECT
    PaymentMethod                                   AS payment_method,
    CASE WHEN PaymentMethod LIKE '%automatic%' THEN 'Automatic' ELSE 'Manual' END AS payment_mode,
    COUNT(*)                                        AS customers,
    SUM(is_churned)                                 AS churners,
    ROUND(100.0 * SUM(is_churned) / COUNT(*), 2)     AS churn_rate_pct,
    ROUND((1.0 * SUM(is_churned) / COUNT(*))
          / ((SELECT 1.0 * SUM(is_churned) / COUNT(*) FROM v_customers)), 2) AS lift
FROM v_customers
GROUP BY PaymentMethod
ORDER BY churn_rate_pct DESC;

SELECT * FROM v_churn_by_payment;

-- ---------------------------------------------------------------------------
-- BQ7. Services: internet type, support level, security, billing paper.
-- ---------------------------------------------------------------------------
DROP VIEW IF EXISTS v_churn_by_service;
CREATE VIEW v_churn_by_service AS
SELECT 'Internet service' AS service, InternetService AS level,
       COUNT(*) AS customers, SUM(is_churned) AS churners,
       ROUND(100.0 * SUM(is_churned) / COUNT(*), 2) AS churn_rate_pct
FROM v_customers GROUP BY InternetService
UNION ALL
SELECT 'Tech support', TechSupport, COUNT(*), SUM(is_churned),
       ROUND(100.0 * SUM(is_churned) / COUNT(*), 2) FROM v_customers GROUP BY TechSupport
UNION ALL
SELECT 'Online security', OnlineSecurity, COUNT(*), SUM(is_churned),
       ROUND(100.0 * SUM(is_churned) / COUNT(*), 2) FROM v_customers GROUP BY OnlineSecurity
UNION ALL
SELECT 'Online backup', OnlineBackup, COUNT(*), SUM(is_churned),
       ROUND(100.0 * SUM(is_churned) / COUNT(*), 2) FROM v_customers GROUP BY OnlineBackup
UNION ALL
SELECT 'Device protection', DeviceProtection, COUNT(*), SUM(is_churned),
       ROUND(100.0 * SUM(is_churned) / COUNT(*), 2) FROM v_customers GROUP BY DeviceProtection
UNION ALL
SELECT 'Paperless billing', PaperlessBilling, COUNT(*), SUM(is_churned),
       ROUND(100.0 * SUM(is_churned) / COUNT(*), 2) FROM v_customers GROUP BY PaperlessBilling
ORDER BY service, churn_rate_pct DESC;

SELECT * FROM v_churn_by_service;

-- ---------------------------------------------------------------------------
-- BQ8. Where two strong drivers intersect. Two-year contracts show 0.00% churn
--      through month 24 - a structural fact, not a rounding artefact.
-- ---------------------------------------------------------------------------
DROP VIEW IF EXISTS v_contract_tenure_matrix;
CREATE VIEW v_contract_tenure_matrix AS
SELECT
    Contract                                     AS contract,
    tenure_band,
    COUNT(*)                                     AS customers,
    SUM(is_churned)                              AS churners,
    ROUND(100.0 * SUM(is_churned) / COUNT(*), 2) AS churn_rate_pct
FROM v_customers
GROUP BY Contract, tenure_band
ORDER BY Contract, CASE tenure_band
    WHEN '0-6' THEN 1 WHEN '7-12' THEN 2 WHEN '13-24' THEN 3 WHEN '25-36' THEN 4
    WHEN '37-48' THEN 5 WHEN '49-60' THEN 6 ELSE 7 END;

SELECT * FROM v_contract_tenure_matrix;
