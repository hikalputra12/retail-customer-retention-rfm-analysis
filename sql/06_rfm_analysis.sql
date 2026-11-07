-- 1. Preview customer RFM metrics
SELECT
    customer_id,
    first_purchase_date,
    last_purchase_date,
    recency_days,
    frequency,
    ROUND(monetary, 2) AS monetary
FROM analytics.customer_rfm
ORDER BY monetary DESC, customer_id
LIMIT 10;

-- 2. Customer segment summary
SELECT
    customer_segment,
    COUNT(*) AS customers,
    ROUND(AVG(recency_days), 1) AS avg_recency_days,
    ROUND(AVG(frequency), 2) AS avg_frequency,
    ROUND(SUM(monetary), 2) AS purchase_value,
    ROUND(
        100.0 * SUM(monetary)
        / NULLIF(SUM(SUM(monetary)) OVER (), 0),
        2
    ) AS purchase_value_share_pct
FROM analytics.customer_segments
GROUP BY customer_segment
ORDER BY SUM(monetary) DESC;

-- 3. Validate customer RFM and segmentation
SELECT
    COUNT(*) AS segment_rows,
    COUNT(DISTINCT customer_id) AS unique_customers,
    COUNT(*) FILTER (
        WHERE customer_segment IS NULL
    ) AS missing_segments,
    COUNT(*) FILTER (
        WHERE recency_days < 1
           OR frequency < 1
           OR monetary <= 0
    ) AS invalid_rfm_rows,
    SUM(frequency) AS total_purchase_invoices,
    SUM(monetary) AS total_purchase_value
FROM analytics.customer_segments;