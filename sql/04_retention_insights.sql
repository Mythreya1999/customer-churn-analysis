-- ============================================================================
-- 04_retention_insights.sql
-- Stage 4: turn the analysis into a priority list the business can act on.
-- The tiers are NOT asserted - they are derived from an explainable points
-- scorecard whose cut-offs are set where the observed churn rate steps up.
-- ============================================================================

-- ---------------------------------------------------------------------------
-- BQ16. The evidence for the tiers: churn rate at every score value.
--       This table is why the cut-offs in BQ17 are where they are. If the rate
--       does not step up monotonically, the scorecard is wrong and no tier can
--       rescue it.
-- ---------------------------------------------------------------------------
SELECT
    risk_points,
    COUNT(*)                                        AS customers,
    SUM(is_churned)                                 AS churners,
    ROUND(100.0 * SUM(is_churned) / COUNT(*), 2)     AS churn_rate_pct,
    ROUND(SUM(CASE WHEN is_churned = 1 THEN monthly_charges ELSE 0 END), 2) AS mrr_lost
FROM v_customers
GROUP BY risk_points
ORDER BY risk_points;

-- ---------------------------------------------------------------------------
-- BQ17. Priority tiers. Cut-offs: HIGH >= 8 points, MEDIUM 5-7, LOW <= 4.
--       The multiple column is what justifies acting: a tier churning at 3-4x
--       base is a different business decision from one at 0.3x.
-- ---------------------------------------------------------------------------
CREATE VIEW v_priority_tiers AS
WITH tiered AS (
    SELECT
        customerID, is_churned, monthly_charges, tenure_months,
        CASE
            WHEN risk_points >= 8 THEN '1. HIGH'
            WHEN risk_points >= 5 THEN '2. MEDIUM'
            ELSE                       '3. LOW'
        END                                            AS priority_tier,
        risk_points
    FROM v_customers
)
SELECT
    priority_tier,
    COUNT(*)                                          AS customers,
    SUM(is_churned)                                   AS churners,
    ROUND(100.0 * SUM(is_churned) / COUNT(*), 2)       AS churn_rate_pct,
    ROUND(100.0 * COUNT(*) / (SELECT COUNT(*) FROM v_customers), 2)               AS pct_of_base,
    ROUND(100.0 * SUM(is_churned) / (SELECT SUM(is_churned) FROM v_customers), 2) AS pct_of_all_churners,
    ROUND((1.0 * SUM(is_churned) / COUNT(*))
          / ((SELECT 1.0 * SUM(is_churned) / COUNT(*) FROM v_customers)), 2)      AS multiple_of_base_rate,
    ROUND(SUM(CASE WHEN is_churned = 1 THEN monthly_charges ELSE 0 END), 2)       AS mrr_lost,
    ROUND(SUM(CASE WHEN is_churned = 1 THEN monthly_charges ELSE 0 END) * 12, 2)  AS arr_exposure,
    ROUND(MIN(risk_points), 0) AS min_score,
    ROUND(MAX(risk_points), 0) AS max_score
FROM tiered
GROUP BY priority_tier
ORDER BY priority_tier;

SELECT * FROM v_priority_tiers;

-- ---------------------------------------------------------------------------
-- BQ18. Who is actually in the HIGH tier? A priority list nobody can describe
--       operationally is not a priority list.
-- ---------------------------------------------------------------------------
SELECT
    Contract                                       AS contract,
    CASE WHEN tenure_months <= 6  THEN '0-6'
         WHEN tenure_months <= 12 THEN '7-12'
         WHEN tenure_months <= 24 THEN '13-24' ELSE '25+' END AS tenure_bucket,
    PaymentMethod                                  AS payment_method,
    COUNT(*)                                       AS customers,
    SUM(is_churned)                                AS churners,
    ROUND(100.0 * SUM(is_churned) / COUNT(*), 2)    AS churn_rate_pct,
    ROUND(SUM(CASE WHEN is_churned = 1 THEN monthly_charges ELSE 0 END), 2) AS mrr_lost
FROM v_customers
WHERE risk_points >= 8
GROUP BY Contract, tenure_bucket, PaymentMethod
HAVING COUNT(*) >= 20
ORDER BY mrr_lost DESC
LIMIT 12;

-- ---------------------------------------------------------------------------
-- BQ19. Pareto: how small a slice of the base holds 80% of the churn? Ordered by
--       score, this says how many customers a retention team must touch.
-- ---------------------------------------------------------------------------
WITH ordered AS (
    SELECT
        customerID, is_churned, risk_points,
        ROW_NUMBER() OVER (ORDER BY risk_points DESC, monthly_charges DESC) AS rn,
        COUNT(*) OVER () AS total_customers,
        SUM(is_churned) OVER () AS total_churners,
        SUM(is_churned) OVER (
            ORDER BY risk_points DESC, monthly_charges DESC
            ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
        ) AS running_churners
    FROM v_customers
)
SELECT
    MIN(rn)                                                                AS customers_needed,
    ROUND(100.0 * MIN(rn) / MIN(total_customers), 2)                        AS pct_of_base,
    ROUND(100.0 * MIN(running_churners) / MIN(total_churners), 2)           AS pct_of_churn_captured
FROM ordered
WHERE 1.0 * running_churners / total_churners >= 0.80;

-- ---------------------------------------------------------------------------
-- BQ20. The action table: one row per tier, with the intervention and the size
--       of the prize. This is the deliverable a retention manager acts on.
-- ---------------------------------------------------------------------------
SELECT
    t.priority_tier,
    t.customers,
    t.churners,
    t.churn_rate_pct,
    t.mrr_lost,
    t.arr_exposure,
    CASE t.priority_tier
        WHEN '1. HIGH'   THEN 'Personal retention call within 14 days; offer contract upgrade with tech support bundled'
        WHEN '2. MEDIUM' THEN 'Automated multi-channel campaign; nudge e-check to automatic payment'
        ELSE                  'No outreach; loyalty programme and referral only'
    END                                              AS recommended_action,
    CASE t.priority_tier
        WHEN '1. HIGH'   THEN 'Named agent, 30-day SLA'
        WHEN '2. MEDIUM' THEN 'Marketing automation'
        ELSE                  'Self-serve'
    END                                              AS owner,
    CASE t.priority_tier
        WHEN '1. HIGH'   THEN 'Churn rate and 90-day save rate on the HIGH cohort'
        WHEN '2. MEDIUM' THEN 'Conversion of e-check to automatic payment'
        ELSE                  'Watch for reclassification into MEDIUM'
    END                                              AS success_metric
FROM v_priority_tiers t
ORDER BY t.priority_tier;

-- ---------------------------------------------------------------------------
-- BQ20b. Revenue exposure, as one governed view. Run-rate exposure, NOT realised
--        loss and NOT CLV (no margin, no cost-to-serve in this dataset).
-- ---------------------------------------------------------------------------
DROP VIEW IF EXISTS v_revenue_at_risk;
CREATE VIEW v_revenue_at_risk AS
SELECT
    ROUND(SUM(CASE WHEN is_churned = 1 THEN monthly_charges ELSE 0 END), 2)      AS mrr_lost,
    ROUND(SUM(CASE WHEN is_churned = 1 THEN monthly_charges ELSE 0 END) * 12, 2) AS arr_exposure,
    ROUND(SUM(monthly_charges), 2)                                               AS mrr_total,
    ROUND(SUM(monthly_charges) * 12, 2)                                          AS arr_total,
    ROUND(100.0 * SUM(CASE WHEN is_churned = 1 THEN monthly_charges ELSE 0 END)
          / SUM(monthly_charges), 2)                                             AS pct_mrr_exposed,
    ROUND(AVG(CASE WHEN is_churned = 1 THEN monthly_charges END), 2)             AS avg_mc_churner,
    ROUND(AVG(CASE WHEN is_churned = 0 THEN monthly_charges END), 2)             AS avg_mc_retained,
    ROUND(AVG(CASE WHEN is_churned = 1 THEN monthly_charges END)
          - AVG(CASE WHEN is_churned = 0 THEN monthly_charges END), 2)           AS charge_delta
FROM v_customers;

SELECT * FROM v_revenue_at_risk;

-- ---------------------------------------------------------------------------
-- BQ21. Segment-level revenue exposure, ranked, for budget allocation.
--       Churn rate alone misleads: a small high-rate cell can cost less than a
--       large medium-rate one.
-- ---------------------------------------------------------------------------
WITH by_contract AS (
    SELECT
        Contract                                    AS segment,
        COUNT(*)                                     AS customers,
        SUM(is_churned)                              AS churners,
        ROUND(100.0 * SUM(is_churned) / COUNT(*), 2)  AS churn_rate_pct,
        SUM(CASE WHEN is_churned = 1 THEN monthly_charges ELSE 0 END) AS mrr_lost
    FROM v_customers
    GROUP BY Contract
)
SELECT
    segment, customers, churners, churn_rate_pct,
    ROUND(mrr_lost, 2)                             AS mrr_lost,
    ROUND(mrr_lost * 12, 2)                        AS arr_exposure,
    ROUND(100.0 * mrr_lost / (SELECT SUM(mrr_lost) FROM by_contract), 2) AS pct_of_total_exposure,
    RANK() OVER (ORDER BY mrr_lost DESC)           AS exposure_rank
FROM by_contract
ORDER BY exposure_rank;

-- ---------------------------------------------------------------------------
-- BQ22. Integrity: the tiers must partition the base and stay monotone.
--       A tiering that overlaps or inverts is worse than no tiering.
-- ---------------------------------------------------------------------------
WITH checks AS (
    SELECT 'tiers_sum_to_base' AS check_name,
           CAST((SELECT SUM(customers) FROM v_priority_tiers) AS TEXT) AS actual,
           '7043' AS expected
    UNION ALL
    SELECT 'tiers_sum_churners',
           CAST((SELECT SUM(churners) FROM v_priority_tiers) AS TEXT), '1869'
    UNION ALL
    SELECT 'high_tier_rate_above_medium',
           CAST(CASE WHEN (SELECT churn_rate_pct FROM v_priority_tiers WHERE priority_tier = '1. HIGH')
                      > (SELECT churn_rate_pct FROM v_priority_tiers WHERE priority_tier = '2. MEDIUM')
                 THEN 'PASS' ELSE 'FAIL' END AS TEXT), 'PASS'
    UNION ALL
    SELECT 'medium_tier_rate_above_low',
           CAST(CASE WHEN (SELECT churn_rate_pct FROM v_priority_tiers WHERE priority_tier = '2. MEDIUM')
                      > (SELECT churn_rate_pct FROM v_priority_tiers WHERE priority_tier = '3. LOW')
                 THEN 'PASS' ELSE 'FAIL' END AS TEXT), 'PASS'
    UNION ALL
    SELECT 'high_tier_rate_above_base',
           CAST(CASE WHEN (SELECT churn_rate_pct FROM v_priority_tiers WHERE priority_tier = '1. HIGH') > 26.54
                 THEN 'PASS' ELSE 'FAIL' END AS TEXT), 'PASS'
)
SELECT * FROM checks;
