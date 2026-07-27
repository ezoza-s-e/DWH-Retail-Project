-- ============================================================
-- FACT TABLE PARTITIONING STRATEGY
-- ============================================================

CREATE TABLE dm.fct_sales_2022 PARTITION OF dm.fct_sales
    FOR VALUES FROM (20220101) TO (20230101);

CREATE TABLE dm.fct_sales_2023 PARTITION OF dm.fct_sales
    FOR VALUES FROM (20230101) TO (20240101);

CREATE TABLE dm.fct_sales_2024 PARTITION OF dm.fct_sales
    FOR VALUES FROM (20240101) TO (20250101);

CREATE TABLE dm.fct_sales_2025 PARTITION OF dm.fct_sales
    FOR VALUES FROM (20250101) TO (20260101);

CREATE TABLE dm.fct_sales_2026 PARTITION OF dm.fct_sales
    FOR VALUES FROM (20260101) TO (20270101);


CREATE TABLE dm.fct_sales_2027 PARTITION OF dm.fct_sales
    FOR VALUES FROM (20270101) TO (20280101);


CREATE INDEX ON dm.fct_sales (customer_surr_id);
CREATE INDEX ON dm.fct_sales (product_surr_id);
CREATE INDEX ON dm.fct_sales (geography_id);
CREATE INDEX ON dm.fct_sales (channel);


