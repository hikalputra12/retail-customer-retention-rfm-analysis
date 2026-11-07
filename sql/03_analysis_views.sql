-- 1. Eligible purchase lines
-- Period: December 2010–November 2011
-- Positive purchases from identified customers.
-- Excludes shipping, bank charges, and ambiguous manual entries.
-- Identical source rows are retained.

CREATE OR REPLACE VIEW analytics.purchase_lines AS
SELECT
    source_row_id,
    invoice_no,
    stock_code,
    description,
    quantity,
    invoice_date,
    unit_price,
    customer_id,
    country,
    quantity * unit_price AS line_value
FROM raw.retail_lines
WHERE NULLIF(TRIM(customer_id), '') IS NOT NULL
  AND NULLIF(TRIM(invoice_no), '') IS NOT NULL
  AND UPPER(invoice_no) NOT LIKE 'C%'
  AND quantity > 0
  AND unit_price > 0
  AND invoice_date >= TIMESTAMP '2010-12-01'
  AND invoice_date < TIMESTAMP '2011-12-01'
  AND COALESCE(UPPER(TRIM(stock_code)), '') NOT IN (
      'POST',
      'C2',
      'DOT',
      'BANK CHARGES',
      'M'
  );
  
  -- 2. Validate the eligible purchase population
SELECT
    COUNT(*) AS purchase_lines,
    COUNT(DISTINCT invoice_no) AS purchase_invoices,
    COUNT(DISTINCT customer_id) AS customers,
    SUM(line_value) AS purchase_value
FROM analytics.purchase_lines;

-- 3. Aggregate eligible purchase lines into invoices
CREATE OR REPLACE VIEW analytics.purchase_invoices AS
SELECT
    customer_id,
    invoice_no,
    MIN(invoice_date) AS purchase_date,
    COUNT(*) AS line_count,
    SUM(quantity) AS total_quantity,
    SUM(line_value) AS invoice_value
FROM analytics.purchase_lines
GROUP BY
    customer_id,
    invoice_no;

    -- 4. Validate invoice aggregation
SELECT
    COUNT(*) AS purchase_invoices,
    COUNT(DISTINCT customer_id) AS customers,
    SUM(line_count) AS purchase_lines,
    SUM(invoice_value) AS purchase_value
FROM analytics.purchase_invoices;

-- 5. Customer monthly activity and first observed purchase month
CREATE OR REPLACE VIEW analytics.customer_monthly_activity AS
WITH monthly_activity AS (
    SELECT DISTINCT
        customer_id,
        DATE_TRUNC('month', purchase_date)::date AS purchase_month
    FROM analytics.purchase_invoices
)
SELECT
    customer_id,
    purchase_month,
    MIN(purchase_month) OVER (
        PARTITION BY customer_id
    ) AS cohort_month
FROM monthly_activity;

-- 6. Customer RFM metrics as of 1 December 2011
CREATE OR REPLACE VIEW analytics.customer_rfm AS
SELECT
    customer_id,
    MIN(purchase_date)::date AS first_purchase_date,
    MAX(purchase_date)::date AS last_purchase_date,
    DATE '2011-12-01'
        - MAX(purchase_date)::date AS recency_days,
    COUNT(*) AS frequency,
    SUM(invoice_value) AS monetary
FROM analytics.purchase_invoices
GROUP BY customer_id;

-- 7. Rule-based customer segmentation
-- Operational assumptions: recency thresholds of 30 and 90 days.
-- High value: monetary at or above the 75th percentile.
CREATE OR REPLACE VIEW analytics.customer_segments AS
WITH monetary_threshold AS (
    SELECT
        PERCENTILE_DISC(0.75) WITHIN GROUP (
            ORDER BY monetary
        ) AS high_value_threshold
    FROM analytics.customer_rfm
)
SELECT
    r.*,
    t.high_value_threshold,
    CASE
        WHEN r.recency_days <= 30
             AND r.frequency >= 2
             AND r.monetary >= t.high_value_threshold
            THEN 'High-value active repeat'
        WHEN r.recency_days <= 30
             AND r.frequency >= 2
            THEN 'Active repeat'
        WHEN r.recency_days <= 30
            THEN 'Recent single-purchase'
        WHEN r.recency_days <= 90
            THEN 'Cooling'
        WHEN r.monetary >= t.high_value_threshold
            THEN 'High-value inactive'
        ELSE 'Other inactive'
    END AS customer_segment
FROM analytics.customer_rfm AS r
CROSS JOIN monetary_threshold AS t;