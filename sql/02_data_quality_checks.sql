-- 1. Compare imported data with the Power Query summary
SELECT
    COUNT(*) AS total_rows,

    COUNT(*) FILTER (
        WHERE NULLIF(BTRIM(customer_id), '') IS NULL
    ) AS missing_customer_id,

    COUNT(*) FILTER (
        WHERE UPPER(BTRIM(invoice_no)) LIKE 'C%'
    ) AS cancellation_rows,

    COUNT(*) FILTER (
        WHERE quantity < 0
    ) AS negative_quantity,

    COUNT(*) FILTER (
        WHERE quantity = 0
    ) AS zero_quantity,

    COUNT(*) FILTER (
        WHERE unit_price <= 0
    ) AS non_positive_unit_price,

    COUNT(*) FILTER (
        WHERE invoice_date IS NULL
    ) AS missing_invoice_date,

    MIN(invoice_date) AS first_invoice_date,
    MAX(invoice_date) AS last_invoice_date

FROM raw.retail_lines;

-- 2. Verify the date interpretation on a known invoice
SELECT
    invoice_no,
    invoice_date,
    unit_price,
    customer_id
FROM raw.retail_lines
WHERE invoice_no = '536365'
ORDER BY source_row_id
LIMIT 3;


-- 3. Check invoices linked to multiple identified customers
SELECT
    invoice_no,
    COUNT(DISTINCT NULLIF(BTRIM(customer_id), ''))
        AS distinct_customers
FROM raw.retail_lines
GROUP BY invoice_no
HAVING COUNT(DISTINCT NULLIF(BTRIM(customer_id), '')) > 1
ORDER BY distinct_customers DESC, invoice_no;

-- 4. Count exact duplicate groups and additional rows
WITH duplicate_groups AS (
    SELECT
        invoice_no,
        stock_code,
        description,
        quantity,
        invoice_date,
        unit_price,
        customer_id,
        country,
        COUNT(*) AS occurrences
    FROM raw.retail_lines
    GROUP BY
        invoice_no,
        stock_code,
        description,
        quantity,
        invoice_date,
        unit_price,
        customer_id,
        country
    HAVING COUNT(*) > 1
)
SELECT
    COUNT(*) AS duplicate_groups,
    COALESCE(SUM(occurrences - 1), 0)
        AS additional_duplicate_rows
FROM duplicate_groups;

-- 5. Inspect the most repeated identical rows
SELECT
    invoice_no,
    stock_code,
    description,
    quantity,
    invoice_date,
    unit_price,
    customer_id,
    country,
    COUNT(*) AS occurrences
FROM raw.retail_lines
GROUP BY
    invoice_no,
    stock_code,
    description,
    quantity,
    invoice_date,
    unit_price,
    customer_id,
    country
HAVING COUNT(*) > 1
ORDER BY occurrences DESC, invoice_no, stock_code
LIMIT 5;

-- 6. Compare cancellation flags with quantity signs
SELECT
    CASE
        WHEN NULLIF(BTRIM(invoice_no), '') IS NULL
            THEN 'Missing invoice'
        WHEN UPPER(BTRIM(invoice_no)) LIKE 'C%'
            THEN 'Cancellation'
        ELSE 'Other invoice'
    END AS invoice_type,

    CASE
        WHEN quantity < 0 THEN 'Negative'
        WHEN quantity = 0 THEN 'Zero'
        WHEN quantity > 0 THEN 'Positive'
        ELSE 'Missing'
    END AS quantity_type,

    COUNT(*) AS total_rows

FROM raw.retail_lines
GROUP BY 1, 2
ORDER BY 1, 2;


-- 7. Compare purchase totals with and without exact duplicates
WITH candidate_purchases AS (
    SELECT
        *,
        ROW_NUMBER() OVER (
            PARTITION BY
                invoice_no,
                stock_code,
                description,
                quantity,
                invoice_date,
                unit_price,
                customer_id,
                country
            ORDER BY source_row_id
        ) AS duplicate_rank
    FROM raw.retail_lines
    WHERE NULLIF(BTRIM(customer_id), '') IS NOT NULL
      AND NULLIF(BTRIM(invoice_no), '') IS NOT NULL
      AND UPPER(BTRIM(invoice_no)) NOT LIKE 'C%'
      AND quantity > 0
      AND unit_price > 0
      AND invoice_date >= TIMESTAMP '2010-12-01'
      AND invoice_date < TIMESTAMP '2011-12-01'
)
SELECT
    COUNT(*) AS rows_before_dedup,

    COUNT(*) FILTER (
        WHERE duplicate_rank = 1
    ) AS rows_after_dedup,

    SUM(quantity * unit_price)
        AS purchase_value_before_dedup,

    SUM(quantity * unit_price) FILTER (
        WHERE duplicate_rank = 1
    ) AS purchase_value_after_dedup,

    COALESCE(
        SUM(quantity * unit_price) FILTER (
            WHERE duplicate_rank > 1
        ),
        0
    ) AS purchase_value_difference

FROM candidate_purchases;

-- 8. Inspect stock codes that do not start with a number
-- within the candidate purchase population
SELECT
    stock_code,
    COUNT(*) AS line_count,
    MIN(description) AS example_description,
    SUM(quantity * unit_price) AS transaction_value
FROM raw.retail_lines
WHERE NULLIF(TRIM(customer_id), '') IS NOT NULL
  AND NULLIF(TRIM(invoice_no), '') IS NOT NULL
  AND UPPER(invoice_no) NOT LIKE 'C%'
  AND quantity > 0
  AND unit_price > 0
  AND invoice_date >= TIMESTAMP '2010-12-01'
  AND invoice_date < TIMESTAMP '2011-12-01'
  AND stock_code !~ '^[0-9]'
GROUP BY stock_code
ORDER BY line_count DESC;

