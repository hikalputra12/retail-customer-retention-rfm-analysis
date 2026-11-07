-- 1. Monthly cohort retention
WITH cohort_sizes AS (
    SELECT
        cohort_month,
        COUNT(*) AS cohort_customers
    FROM analytics.customer_monthly_activity
    WHERE purchase_month = cohort_month
    GROUP BY cohort_month
),
cohort_activity AS (
    SELECT
        cohort_month,
        purchase_month,
        COUNT(*) AS active_customers
    FROM analytics.customer_monthly_activity
    GROUP BY
        cohort_month,
        purchase_month
),
cohort_grid AS (
    SELECT
        cs.cohort_month,
        cs.cohort_customers,
        gs.activity_month::date AS purchase_month
    FROM cohort_sizes AS cs
    CROSS JOIN LATERAL GENERATE_SERIES(
        cs.cohort_month::timestamp,
        TIMESTAMP '2011-11-01',
        INTERVAL '1 month'
    ) AS gs(activity_month)
)
SELECT
    cg.cohort_month,
    cg.purchase_month,
    (
        (EXTRACT(YEAR FROM cg.purchase_month)::int
         - EXTRACT(YEAR FROM cg.cohort_month)::int) * 12
        + EXTRACT(MONTH FROM cg.purchase_month)::int
        - EXTRACT(MONTH FROM cg.cohort_month)::int
    ) AS month_index,
    cg.cohort_customers,
    COALESCE(ca.active_customers, 0) AS active_customers,
    ROUND(
        100.0 * COALESCE(ca.active_customers, 0)
        / NULLIF(cg.cohort_customers, 0),
        2
    ) AS retention_rate_pct
FROM cohort_grid AS cg
LEFT JOIN cohort_activity AS ca
    ON cg.cohort_month = ca.cohort_month
   AND cg.purchase_month = ca.purchase_month
ORDER BY
    cg.cohort_month,
    month_index;