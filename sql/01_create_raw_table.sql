CREATE SCHEMA IF NOT EXISTS raw;
CREATE SCHEMA IF NOT EXISTS analytics;

CREATE TABLE raw.retail_lines (
    invoice_no TEXT,
    stock_code TEXT,
    description TEXT,
    quantity INTEGER,
    invoice_date TIMESTAMP,
    unit_price NUMERIC,
    customer_id TEXT,
    country TEXT,
    source_row_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY
);

-- Configure date interpretation for new database connections.
-- Source CSV uses month/day/year.
ALTER DATABASE retail_analytics
SET datestyle TO 'ISO, MDY';