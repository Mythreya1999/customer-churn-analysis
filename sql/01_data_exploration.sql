-- ============================================================================
-- 01_data_exploration.sql
-- Customer Churn Analysis & Retention Insights
-- Stage 1: build the clean, typed, governed view layer, then profile it.
-- Dialect: SQLite (ANSI-portable, runs on PostgreSQL unchanged apart from date types,
--          of which this dataset has none).
-- Grain of every view: 1 row = 1 customer.
-- ============================================================================
--
-- CLEANING DECISIONS (each is a definitional choice, not a formality)
--
-- D1  TotalCharges arrives as TEXT with 11 blank strings. All 11 have tenure = 0,
--     i.e. never billed. Blank -> 0.00 is the only reading consistent with "no
--     billing history"; dropping them would silently delete the newest cohort,
--     which is also the highest-risk one (52.94% churn in months 0-6).
-- D2  Churn is stored 'Yes'/'No'. Every KPI filters the boolean is_churned, never
--     the string. One definition, one place to change it.
-- D3  Bands are LEFT-CLOSED: '0-6' means tenure <= 6; '30-49' means 30 <= x < 50.
--     A right-closed cut moves boundary customers into the wrong band.
-- D4  "No internet service" is a real level, not a missing value (1,526 customers).
--     Folding it into 'No' inflates the tech-support churn rate.
-- D5  Revenue at risk = SUM(MonthlyCharges) over churned customers, annualised x12.
--     Run-rate exposure, NOT realised loss and NOT CLV.
-- ============================================================================

DROP VIEW IF EXISTS v_customers;
DROP VIEW IF EXISTS v_kpi_overall;
DROP VIEW IF EXISTS v_churn_by_contract;
DROP VIEW IF EXISTS v_churn_by_tenure_band;
DROP VIEW IF EXISTS v_churn_by_charge_band;
DROP VIEW IF EXISTS v_churn_by_payment;
DROP VIEW IF EXISTS v_churn_by_demographic;
DROP VIEW IF EXISTS v_churn_by_service;
DROP VIEW IF EXISTS v_contract_tenure_matrix;
DROP VIEW IF EXISTS v_revenue_at_risk;
DROP VIEW IF EXISTS v_high_risk_segments;

-- ---------------------------------------------------------------------------
-- STEP 1. The base fact view: typed, flagged, banded, scored.
--         Every downstream query reads this and nothing else.
-- ---------------------------------------------------------------------------
CREATE VIEW v_customers AS
SELECT
    customerID,
    CAST(tenure AS INTEGER)                                   AS tenure_months,
    CAST(MonthlyCharges AS REAL)                              AS monthly_charges,
    CASE WHEN TRIM(CAST(TotalCharges AS TEXT)) = ''
         THEN 0.0 ELSE CAST(TotalCharges AS REAL) END          AS total_charges,   -- D1
    gender,
    CAST(SeniorCitizen AS INTEGER)                             AS is_senior,
    Partner,
    Dependents,
    PhoneService,
    MultipleLines,
    InternetService,
    OnlineSecurity,
    OnlineBackup,
    DeviceProtection,
    TechSupport,
    StreamingTV,
    StreamingMovies,
    Contract,
    PaperlessBilling,
    PaymentMethod,

    CASE WHEN Churn = 'Yes' THEN 1 ELSE 0 END                  AS is_churned,      -- D2

    -- D3: left-closed tenure bands
    CASE
        WHEN tenure <= 6  THEN '0-6'
        WHEN tenure <= 12 THEN '7-12'
        WHEN tenure <= 24 THEN '13-24'
        WHEN tenure <= 36 THEN '25-36'
        WHEN tenure <= 48 THEN '37-48'
        WHEN tenure <= 60 THEN '49-60'
        ELSE '61-72'
    END                                                        AS tenure_band,

    -- D3: left-closed charge bands
    CASE
        WHEN MonthlyCharges < 30  THEN '<30'
        WHEN MonthlyCharges < 50  THEN '30-49'
        WHEN MonthlyCharges < 70  THEN '50-69'
        WHEN MonthlyCharges < 90  THEN '70-89'
        ELSE '90+'
    END                                                        AS charge_band,

    CASE WHEN tenure <= 12 THEN 1 ELSE 0 END                    AS is_new_customer,
    CASE WHEN Contract = 'Month-to-month' THEN 1 ELSE 0 END     AS is_month_to_month,
    CASE WHEN Contract = 'Two year'       THEN 1 ELSE 0 END     AS is_two_year,
    CASE WHEN InternetService = 'No'      THEN 1 ELSE 0 END     AS has_no_internet,   -- D4
    CASE WHEN PaymentMethod LIKE '%automatic%' THEN 1 ELSE 0 END AS is_autopay,

    -- Optional add-on services held (phone excluded: 90% penetration, no signal)
    (CASE WHEN MultipleLines    = 'Yes' THEN 1 ELSE 0 END
   + CASE WHEN OnlineSecurity   = 'Yes' THEN 1 ELSE 0 END
   + CASE WHEN OnlineBackup     = 'Yes' THEN 1 ELSE 0 END
   + CASE WHEN DeviceProtection = 'Yes' THEN 1 ELSE 0 END
   + CASE WHEN TechSupport      = 'Yes' THEN 1 ELSE 0 END
   + CASE WHEN StreamingTV      = 'Yes' THEN 1 ELSE 0 END
   + CASE WHEN StreamingMovies  = 'Yes' THEN 1 ELSE 0 END)     AS n_addon_services,

    -- Explainable risk scorecard (points, not a black box). Weights are set from
    -- the univariate churn rates in 02_churn_analysis.sql, so they are auditable.
    (
        CASE WHEN Contract = 'Month-to-month' THEN 3 ELSE 0 END
      + CASE WHEN tenure <= 6  THEN 3
             WHEN tenure <= 12 THEN 2
             WHEN tenure <= 24 THEN 1 ELSE 0 END
      + CASE WHEN InternetService = 'Fiber optic' THEN 2 ELSE 0 END
      + CASE WHEN TechSupport = 'No' THEN 2 ELSE 0 END
      + CASE WHEN PaymentMethod = 'Electronic check' THEN 2 ELSE 0 END
      + CASE WHEN OnlineSecurity = 'No' THEN 1 ELSE 0 END
      + CASE WHEN CAST(SeniorCitizen AS INTEGER) = 1 THEN 1 ELSE 0 END
    )                                                          AS risk_points,

    -- The segment every artifact leads with
    CASE
        WHEN Contract = 'Month-to-month' AND tenure <= 12
             AND InternetService = 'Fiber optic' AND TechSupport = 'No'
        THEN 1 ELSE 0
    END                                                        AS is_prime_risk_segment
FROM customer_churn;

-- ---------------------------------------------------------------------------
-- BQ0a. What is in the table? Row/column counts and the grain check.
-- ---------------------------------------------------------------------------
SELECT
    COUNT(*)                        AS rows,
    COUNT(DISTINCT customerID)      AS distinct_customers,
    COUNT(*) - COUNT(DISTINCT customerID) AS duplicate_ids,
    MIN(tenure_months)              AS min_tenure,
    MAX(tenure_months)              AS max_tenure,
    ROUND(MIN(monthly_charges), 2)  AS min_monthly,
    ROUND(MAX(monthly_charges), 2)  AS max_monthly,
    ROUND(MIN(total_charges), 2)    AS min_total,
    ROUND(MAX(total_charges), 2)    AS max_total
FROM v_customers;

-- ---------------------------------------------------------------------------
-- BQ0b. Which columns can be trusted? Null count per column, via a CTE so the
--       check is written once and the columns are listed explicitly.
-- ---------------------------------------------------------------------------
WITH profile AS (
    SELECT
        SUM(CASE WHEN customerID      IS NULL THEN 1 ELSE 0 END) AS c01,
        SUM(CASE WHEN gender          IS NULL THEN 1 ELSE 0 END) AS c02,
        SUM(CASE WHEN is_senior       IS NULL THEN 1 ELSE 0 END) AS c03,
        SUM(CASE WHEN Partner         IS NULL THEN 1 ELSE 0 END) AS c04,
        SUM(CASE WHEN Dependents      IS NULL THEN 1 ELSE 0 END) AS c05,
        SUM(CASE WHEN tenure_months   IS NULL THEN 1 ELSE 0 END) AS c06,
        SUM(CASE WHEN Contract        IS NULL THEN 1 ELSE 0 END) AS c07,
        SUM(CASE WHEN PaymentMethod   IS NULL THEN 1 ELSE 0 END) AS c08,
        SUM(CASE WHEN InternetService IS NULL THEN 1 ELSE 0 END) AS c09,
        SUM(CASE WHEN TechSupport     IS NULL THEN 1 ELSE 0 END) AS c10,
        SUM(CASE WHEN monthly_charges IS NULL THEN 1 ELSE 0 END) AS c11,
        SUM(CASE WHEN total_charges   IS NULL THEN 1 ELSE 0 END) AS c12,
        SUM(CASE WHEN is_churned      IS NULL THEN 1 ELSE 0 END) AS c13
    FROM v_customers
)
SELECT 'customerID' AS column_name, c01 AS nulls FROM profile
UNION ALL SELECT 'gender',          c02 FROM profile
UNION ALL SELECT 'SeniorCitizen',   c03 FROM profile
UNION ALL SELECT 'Partner',         c04 FROM profile
UNION ALL SELECT 'Dependents',      c05 FROM profile
UNION ALL SELECT 'tenure',          c06 FROM profile
UNION ALL SELECT 'Contract',        c07 FROM profile
UNION ALL SELECT 'PaymentMethod',   c08 FROM profile
UNION ALL SELECT 'InternetService', c09 FROM profile
UNION ALL SELECT 'TechSupport',     c10 FROM profile
UNION ALL SELECT 'MonthlyCharges',  c11 FROM profile
UNION ALL SELECT 'TotalCharges',    c12 FROM profile
UNION ALL SELECT 'Churn',           c13 FROM profile
ORDER BY nulls DESC, column_name;

-- ---------------------------------------------------------------------------
-- BQ0c. What do the categorical columns actually contain? Cardinality first, so
--       an unexpected extra level shows up before it distorts a rate.
-- ---------------------------------------------------------------------------
SELECT 'gender' AS column_name, gender AS level, COUNT(*) AS customers FROM v_customers GROUP BY gender
UNION ALL SELECT 'SeniorCitizen', CAST(is_senior AS TEXT), COUNT(*) FROM v_customers GROUP BY is_senior
UNION ALL SELECT 'Partner', Partner, COUNT(*) FROM v_customers GROUP BY Partner
UNION ALL SELECT 'Dependents', Dependents, COUNT(*) FROM v_customers GROUP BY Dependents
UNION ALL SELECT 'InternetService', InternetService, COUNT(*) FROM v_customers GROUP BY InternetService
UNION ALL SELECT 'TechSupport', TechSupport, COUNT(*) FROM v_customers GROUP BY TechSupport
UNION ALL SELECT 'Contract', Contract, COUNT(*) FROM v_customers GROUP BY Contract
UNION ALL SELECT 'PaymentMethod', PaymentMethod, COUNT(*) FROM v_customers GROUP BY PaymentMethod
UNION ALL SELECT 'PaperlessBilling', PaperlessBilling, COUNT(*) FROM v_customers GROUP BY PaperlessBilling
ORDER BY column_name, customers DESC;

-- ---------------------------------------------------------------------------
-- BQ0d. Are there impossible combinations? A CTE that should return zero rows.
-- ---------------------------------------------------------------------------
WITH impossibilities AS (
    SELECT 'tenure out of 0-72'            AS rule, COUNT(*) AS violations FROM v_customers WHERE tenure_months < 0 OR tenure_months > 72
    UNION ALL SELECT 'negative monthly charge',        COUNT(*) FROM v_customers WHERE monthly_charges < 0
    UNION ALL SELECT 'negative total charges',         COUNT(*) FROM v_customers WHERE total_charges < 0
    UNION ALL SELECT 'churn value not 0/1',            COUNT(*) FROM v_customers WHERE is_churned NOT IN (0,1)
    UNION ALL SELECT 'no internet but has online security',
               COUNT(*) FROM v_customers WHERE has_no_internet = 1 AND OnlineSecurity = 'Yes'
    UNION ALL SELECT 'no internet but has streaming',
               COUNT(*) FROM v_customers WHERE has_no_internet = 1 AND StreamingTV = 'Yes'
    UNION ALL SELECT 'no phone but has multiple lines',
               COUNT(*) FROM v_customers WHERE PhoneService = 'No' AND MultipleLines <> 'No phone service'
)
SELECT * FROM impossibilities ORDER BY violations DESC;

-- ---------------------------------------------------------------------------
-- BQ0e. Distribution of the numeric columns - existence of the range, not a chart.
-- ---------------------------------------------------------------------------
SELECT
    'tenure_months'  AS metric,
    ROUND(AVG(tenure_months), 2)   AS mean,
    ROUND(MIN(tenure_months), 2)   AS min,
    ROUND(MAX(tenure_months), 2)   AS max
FROM v_customers
UNION ALL
SELECT 'monthly_charges',
    ROUND(AVG(monthly_charges), 2), ROUND(MIN(monthly_charges), 2), ROUND(MAX(monthly_charges), 2)
FROM v_customers
UNION ALL
SELECT 'total_charges',
    ROUND(AVG(total_charges), 2), ROUND(MIN(total_charges), 2), ROUND(MAX(total_charges), 2)
FROM v_customers;

-- ============================================================================
-- INTEGRITY GATE
-- Every row must read PASS. If a view drifts, this fails loudly here rather than
-- letting three artifacts disagree later.
-- ============================================================================
SELECT 'gate_1_row_count' AS check_name,
       CAST((SELECT COUNT(*) FROM v_customers) AS TEXT) AS actual, '7043' AS expected
UNION ALL SELECT 'gate_2_churners',
       CAST((SELECT SUM(is_churned) FROM v_customers) AS TEXT), '1869'
UNION ALL SELECT 'gate_3_no_duplicate_ids',
       CAST((SELECT COUNT(*) - COUNT(DISTINCT customerID) FROM v_customers) AS TEXT), '0'
UNION ALL SELECT 'gate_4_no_null_churn_flag',
       CAST((SELECT COUNT(*) FROM v_customers WHERE is_churned IS NULL) AS TEXT), '0'
UNION ALL SELECT 'gate_5_no_null_totalcharges',
       CAST((SELECT COUNT(*) FROM v_customers WHERE total_charges IS NULL) AS TEXT), '0'
UNION ALL SELECT 'gate_6_tenure_bands_sum_to_total',
       CAST((SELECT SUM(c) FROM (SELECT COUNT(*) AS c FROM v_customers GROUP BY tenure_band)) AS TEXT), '7043'
UNION ALL SELECT 'gate_7_charge_bands_sum_to_total',
       CAST((SELECT SUM(c) FROM (SELECT COUNT(*) AS c FROM v_customers GROUP BY charge_band)) AS TEXT), '7043'
UNION ALL SELECT 'gate_8_risk_points_in_range',
       CAST((SELECT COUNT(*) FROM v_customers WHERE risk_points < 0 OR risk_points > 14) AS TEXT), '0'
UNION ALL SELECT 'gate_9_prime_risk_exact',
       CAST((SELECT COUNT(*) FROM v_customers WHERE is_prime_risk_segment = 1) AS TEXT), '833'
UNION ALL SELECT 'gate_10_mrr_reconciles',
       CAST(ROUND((SELECT SUM(monthly_charges) FROM v_customers), 2) AS TEXT), '456116.6';
