-- ============================================================================
-- 03_customer_segmentation.sql
-- Stage 3: who the churners are - demographics, service bundles, spend deciles,
-- and multi-dimension segment cells ranked by risk.
-- ============================================================================

-- ---------------------------------------------------------------------------
-- BQ9. Demographics. Gender is included specifically to show it does NOT matter;
--      a segmentation deliverable that omits the null result invites the reader to
--      assume you never checked.
-- ---------------------------------------------------------------------------
CREATE VIEW v_churn_by_demographic AS
SELECT 'Gender' AS attribute, gender AS segment,
       COUNT(*) AS customers, SUM(is_churned) AS churners,
       ROUND(100.0 * SUM(is_churned) / COUNT(*), 2) AS churn_rate_pct
FROM v_customers GROUP BY gender
UNION ALL
SELECT 'Senior citizen', CASE is_senior WHEN 1 THEN 'Senior' ELSE 'Non-senior' END,
       COUNT(*), SUM(is_churned), ROUND(100.0 * SUM(is_churned) / COUNT(*), 2)
FROM v_customers GROUP BY is_senior
UNION ALL
SELECT 'Partner', Partner, COUNT(*), SUM(is_churned),
       ROUND(100.0 * SUM(is_churned) / COUNT(*), 2)
FROM v_customers GROUP BY Partner
UNION ALL
SELECT 'Dependents', Dependents, COUNT(*), SUM(is_churned),
       ROUND(100.0 * SUM(is_churned) / COUNT(*), 2)
FROM v_customers GROUP BY Dependents
ORDER BY attribute, churn_rate_pct DESC;

SELECT * FROM v_churn_by_demographic;

-- ---------------------------------------------------------------------------
-- BQ10. Family structure combined: does a household anchor retention?
-- ---------------------------------------------------------------------------
SELECT
    Partner || ' partner / ' || Dependents || ' dependents'  AS household,
    COUNT(*)                                                  AS customers,
    SUM(is_churned)                                           AS churners,
    ROUND(100.0 * SUM(is_churned) / COUNT(*), 2)               AS churn_rate_pct,
    ROUND(AVG(monthly_charges), 2)                             AS avg_monthly_charges
FROM v_customers
GROUP BY Partner, Dependents
ORDER BY churn_rate_pct DESC;

-- ---------------------------------------------------------------------------
-- BQ11. Service bundle depth: does holding more add-ons retain customers?
--       n_addon_services is computed in the view layer with a CASE sum, so the
--       definition cannot drift between this query and the dashboard.
-- ---------------------------------------------------------------------------
SELECT
    n_addon_services,
    COUNT(*)                                        AS customers,
    SUM(is_churned)                                 AS churners,
    ROUND(100.0 * SUM(is_churned) / COUNT(*), 2)     AS churn_rate_pct,
    ROUND(AVG(monthly_charges), 2)                   AS avg_monthly_charges,
    ROUND(AVG(tenure_months), 1)                     AS avg_tenure_months,
    RANK() OVER (ORDER BY 1.0 * SUM(is_churned) / COUNT(*) DESC) AS risk_rank
FROM v_customers
GROUP BY n_addon_services
ORDER BY n_addon_services;

-- ---------------------------------------------------------------------------
-- BQ12. Spend deciles via NTILE. Answers "is churn concentrated at the top of the
--       bill?" without imposing arbitrary bands - the deciles come from the data.
-- ---------------------------------------------------------------------------
WITH deciles AS (
    SELECT
        customerID, is_churned, monthly_charges,
        NTILE(10) OVER (ORDER BY monthly_charges) AS spend_decile
    FROM v_customers
)
SELECT
    spend_decile,
    COUNT(*)                                    AS customers,
    SUM(is_churned)                             AS churners,
    ROUND(100.0 * SUM(is_churned) / COUNT(*), 2) AS churn_rate_pct,
    ROUND(MIN(monthly_charges), 2)              AS decile_min_charge,
    ROUND(MAX(monthly_charges), 2)              AS decile_max_charge
FROM deciles
GROUP BY spend_decile
ORDER BY spend_decile;

-- ---------------------------------------------------------------------------
-- BQ13. Ranked segment cells (contract x tenure x payment), with a minimum-size
--       filter so a 3-customer cell with 100% churn cannot top the table.
--       HAVING is the filter that makes the ranking trustworthy.
-- ---------------------------------------------------------------------------
SELECT
    Contract || ' | ' || tenure_band || ' | ' || PaymentMethod AS segment_cell,
    COUNT(*)                                         AS customers,
    SUM(is_churned)                                  AS churners,
    ROUND(100.0 * SUM(is_churned) / COUNT(*), 2)      AS churn_rate_pct,
    ROUND(SUM(CASE WHEN is_churned = 1 THEN monthly_charges ELSE 0 END), 2) AS mrr_lost,
    RANK() OVER (ORDER BY 1.0 * SUM(is_churned) / COUNT(*) DESC)            AS risk_rank
FROM v_customers
GROUP BY Contract, tenure_band, PaymentMethod
HAVING COUNT(*) >= 50
ORDER BY churn_rate_pct DESC
LIMIT 15;

-- ---------------------------------------------------------------------------
-- BQ14. Same cells, largest revenue exposure rather than highest rate. The two
--       rankings disagree, which is the point: rate finds the sick cell, revenue
--       finds the expensive one.
-- ---------------------------------------------------------------------------
WITH cells AS (
    SELECT
        Contract || ' | ' || tenure_band AS segment_cell,
        COUNT(*) AS customers,
        1.0 * SUM(is_churned) / COUNT(*) AS churn_rate,
        SUM(CASE WHEN is_churned = 1 THEN monthly_charges ELSE 0 END) AS mrr_lost
    FROM v_customers
    GROUP BY Contract, tenure_band
    HAVING COUNT(*) >= 50
)
SELECT
    segment_cell,
    customers,
    ROUND(churn_rate * 100, 2)      AS churn_rate_pct,
    ROUND(mrr_lost, 2)              AS mrr_lost,
    ROUND(mrr_lost * 12, 2)         AS arr_exposure,
    RANK() OVER (ORDER BY mrr_lost DESC)          AS revenue_rank,
    RANK() OVER (ORDER BY churn_rate DESC)        AS rate_rank
FROM cells
ORDER BY mrr_lost DESC
LIMIT 15;

-- ---------------------------------------------------------------------------
-- BQ15. The prime-risk cell, stated as a single decidable definition, plus the
--       nested segments that show how each condition changes the rate.
-- ---------------------------------------------------------------------------
CREATE VIEW v_high_risk_segments AS
SELECT 'A. Month-to-month & tenure <= 12' AS segment,
       COUNT(*) AS customers, SUM(is_churned) AS churners,
       ROUND(100.0 * SUM(is_churned) / COUNT(*), 2) AS churn_rate_pct,
       ROUND(SUM(monthly_charges), 2) AS segment_mrr,
       ROUND(SUM(CASE WHEN is_churned = 1 THEN monthly_charges ELSE 0 END), 2) AS mrr_lost
FROM v_customers WHERE is_month_to_month = 1 AND is_new_customer = 1
UNION ALL
SELECT 'B. + Fiber optic',
       COUNT(*), SUM(is_churned), ROUND(100.0 * SUM(is_churned) / COUNT(*), 2),
       ROUND(SUM(monthly_charges), 2),
       ROUND(SUM(CASE WHEN is_churned = 1 THEN monthly_charges ELSE 0 END), 2)
FROM v_customers
WHERE is_month_to_month = 1 AND is_new_customer = 1 AND InternetService = 'Fiber optic'
UNION ALL
SELECT 'C. + no tech support  (prime risk)',
       COUNT(*), SUM(is_churned), ROUND(100.0 * SUM(is_churned) / COUNT(*), 2),
       ROUND(SUM(monthly_charges), 2),
       ROUND(SUM(CASE WHEN is_churned = 1 THEN monthly_charges ELSE 0 END), 2)
FROM v_customers WHERE is_prime_risk_segment = 1
UNION ALL
SELECT 'D. Month-to-month & electronic check',
       COUNT(*), SUM(is_churned), ROUND(100.0 * SUM(is_churned) / COUNT(*), 2),
       ROUND(SUM(monthly_charges), 2),
       ROUND(SUM(CASE WHEN is_churned = 1 THEN monthly_charges ELSE 0 END), 2)
FROM v_customers
WHERE is_month_to_month = 1 AND PaymentMethod = 'Electronic check'
UNION ALL
SELECT 'E. Two year & tenure > 24  (safest)',
       COUNT(*), SUM(is_churned), ROUND(100.0 * SUM(is_churned) / COUNT(*), 2),
       ROUND(SUM(monthly_charges), 2),
       ROUND(SUM(CASE WHEN is_churned = 1 THEN monthly_charges ELSE 0 END), 2)
FROM v_customers WHERE is_two_year = 1 AND tenure_months > 24;

SELECT
    segment, customers, churners, churn_rate_pct,
    ROUND(100.0 * churners / (SELECT SUM(is_churned) FROM v_customers), 2) AS pct_of_all_churners,
    ROUND(100.0 * customers / (SELECT COUNT(*) FROM v_customers), 2)       AS pct_of_base,
    ROUND(churn_rate_pct / (SELECT 100.0 * SUM(is_churned) / COUNT(*) FROM v_customers), 2) AS lift,
    segment_mrr, mrr_lost
FROM v_high_risk_segments;
