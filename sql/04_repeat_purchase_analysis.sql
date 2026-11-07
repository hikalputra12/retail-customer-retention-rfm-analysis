-- 1. Customer repeat purchase summary
WITH customer_purchases AS (
    SELECT
        customer_id,
        COUNT(*) AS purchase_count
    FROM analytics.purchase_invoices
    GROUP BY customer_id
)
SELECT
    COUNT(*) AS total_customers,
    COUNT(*) FILTER (
        WHERE purchase_count = 1
    ) AS one_time_customers,
    COUNT(*) FILTER (
        WHERE purchase_count >= 2
    ) AS repeat_customers,
    ROUND(
        100.0 * COUNT(*) FILTER (
            WHERE purchase_count >= 2
        ) / NULLIF(COUNT(*), 0),
        2
    ) AS repeat_customer_rate_pct
FROM customer_purchases;


-- 2. Purchase value contribution by customer type
WITH customer_purchases AS (
    SELECT
        customer_id,
        COUNT(*) AS purchase_count,
        SUM(invoice_value) AS purchase_value
    FROM analytics.purchase_invoices
    GROUP BY customer_id
),
customer_groups AS (
    SELECT
        customer_id,
        purchase_count,
        purchase_value,
        CASE
            WHEN purchase_count = 1 THEN 'One-time'
            ELSE 'Repeat'
        END AS customer_type
    FROM customer_purchases
)
SELECT
    customer_type,
    COUNT(*) AS customers,
    SUM(purchase_count) AS purchase_invoices,
    ROUND(SUM(purchase_value), 2) AS purchase_value,
    ROUND(
        100.0 * SUM(purchase_value)
        / NULLIF(SUM(SUM(purchase_value)) OVER (), 0),
        2
    ) AS purchase_value_share_pct
FROM customer_groups
GROUP BY customer_type
ORDER BY customer_type;