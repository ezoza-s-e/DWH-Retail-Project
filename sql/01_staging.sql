-- ============================================================
-- STAGING LAYER
-- ============================================================

CREATE EXTENSION IF NOT EXISTS file_fdw;

--DROP SERVER IF EXISTS retail_server CASCADE;
CREATE SERVER retail_server FOREIGN DATA WRAPPER file_fdw;

CREATE SCHEMA IF NOT EXISTS staging;




--DROP FOREIGN TABLE IF EXISTS staging.ext_online_web_store;   --to make code rerunnable

CREATE FOREIGN TABLE staging.ext_online_web_store (
    row_id              varchar(20),
    order_id            varchar(1000),
    order_date          varchar(1000),
    ship_date           varchar(1000),
    customer_id         varchar(1000),
    customer_first_name varchar(1000),
    customer_last_name  varchar(1000),
    customer_phone      varchar(1000),
    customer_segment    varchar(1000),
    geo_postalcode      varchar(1000),
    geo_city            varchar(1000),
    geo_state           varchar(1000),
    geo_country         varchar(1000),
    geo_region          varchar(1000),
    geo_market          varchar(1000),
    product_id          varchar(1000),
    category            varchar(1000),
    sub_category        varchar(1000),
    product_name        varchar(1000),
    product_supplier    varchar(1000),
    sales               varchar(1000),
    quantity            varchar(1000),
    discount            varchar(1000),
    profit              varchar(1000),
    shipping_cost       varchar(1000),
    channel             varchar(1000),
    device_type         varchar(1000),
    payment_method      varchar(1000),
    session_id          varchar(1000)
)
SERVER retail_server
OPTIONS (
    filename 'C:/dwh_data/online_web_store.csv',   -- заменить под своё окружение
    format 'csv',
    header 'true',
    delimiter ';'
);


--DROP FOREIGN TABLE IF EXISTS staging.ext_offline_legacy_erp;

CREATE FOREIGN TABLE staging.ext_offline_legacy_erp (
    row_id              varchar(20),
    order_id            varchar(1000),
    order_date          varchar(1000),
    ship_date           varchar(1000),
    customer_id         varchar(1000),
    customer_first_name varchar(1000),
    customer_last_name  varchar(1000),
    customer_phone      varchar(1000),
    customer_segment    varchar(1000),
    geo_postalcode      varchar(1000),
    geo_city            varchar(1000),
    geo_state           varchar(1000),
    geo_country         varchar(1000),
    geo_region          varchar(1000),
    geo_market          varchar(1000),
    store_type          varchar(1000),
    store_id            varchar(1000),
    store_address       varchar(1000),
    store_phone         varchar(1000),
    store_city          varchar(1000),
    store_state         varchar(1000),
    store_country       varchar(1000),
    product_id          varchar(1000),
    category            varchar(1000),
    sub_category        varchar(1000),
    product_name        varchar(1000),
    product_supplier    varchar(1000),
    sales               varchar(1000),
    quantity            varchar(1000),
    discount            varchar(1000),
    profit              varchar(1000),
    shipping_cost       varchar(1000),
    cashier_id          varchar(1000),
    cashier_first_name  varchar(1000),
    cashier_last_name   varchar(1000),
    cashier_email       varchar(1000),
    cashier_phone       varchar(1000),
    channel             varchar(1000)
)
SERVER retail_server
OPTIONS (
    filename 'C:/dwh_data/offline_legacy_erp.csv',   -- заменить под своё окружение
    format 'csv',
    header 'true',
    delimiter ';'
);




CREATE TABLE IF NOT EXISTS staging.stg_online_web_store (
    row_id              varchar(20),
    order_id            varchar(1000),
    order_date          varchar(1000),
    ship_date           varchar(1000),
    customer_id         varchar(1000),
    customer_first_name varchar(1000),
    customer_last_name  varchar(1000),
    customer_phone      varchar(1000),
    customer_segment    varchar(1000),
    geo_postalcode      varchar(1000),
    geo_city            varchar(1000),
    geo_state           varchar(1000),
    geo_country         varchar(1000),
    geo_region          varchar(1000),
    geo_market          varchar(1000),
    product_id          varchar(1000),
    category            varchar(1000),
    sub_category        varchar(1000),
    product_name        varchar(1000),
    product_supplier    varchar(1000),
    sales               varchar(1000),
    quantity            varchar(1000),
    discount            varchar(1000),
    profit              varchar(1000),
    shipping_cost       varchar(1000),
    channel             varchar(1000),
    device_type         varchar(1000),
    payment_method      varchar(1000),
    session_id          varchar(1000),
    ta_insert_dt        TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);


CREATE TABLE IF NOT EXISTS staging.stg_offline_legacy_erp (
    row_id              varchar(20),
    order_id            varchar(1000),
    order_date          varchar(1000),
    ship_date           varchar(1000),
    customer_id         varchar(1000),
    customer_first_name varchar(1000),
    customer_last_name  varchar(1000),
    customer_phone      varchar(1000),
    customer_segment    varchar(1000),
    geo_postalcode      varchar(1000),
    geo_city            varchar(1000),
    geo_state           varchar(1000),
    geo_country         varchar(1000),
    geo_region          varchar(1000),
    geo_market          varchar(1000),
    store_type          varchar(1000),
    store_id            varchar(1000),
    store_address       varchar(1000),
    store_phone         varchar(1000),
    store_city          varchar(1000),
    store_state         varchar(1000),
    store_country       varchar(1000),
    product_id          varchar(1000),
    category            varchar(1000),
    sub_category        varchar(1000),
    product_name        varchar(1000),
    product_supplier    varchar(1000),
    sales               varchar(1000),
    quantity            varchar(1000),
    discount            varchar(1000),
    profit              varchar(1000),
    shipping_cost       varchar(1000),
    cashier_id          varchar(1000),
    cashier_first_name  varchar(1000),
    cashier_last_name   varchar(1000),
    cashier_email       varchar(1000),
    cashier_phone       varchar(1000),
    channel             varchar(1000),
    ta_insert_dt        TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);




INSERT INTO staging.stg_online_web_store
SELECT DISTINCT e.*, CURRENT_TIMESTAMP
FROM staging.ext_online_web_store e
LEFT JOIN staging.stg_online_web_store s
   ON e.row_id = s.row_id
WHERE s.row_id IS NULL;


INSERT INTO staging.stg_offline_legacy_erp
SELECT DISTINCT e.*, CURRENT_TIMESTAMP
FROM staging.ext_offline_legacy_erp e
LEFT JOIN staging.stg_offline_legacy_erp s
   ON e.row_id = s.row_id
WHERE s.row_id IS NULL;


-- ---------------------------------------------------------
-- Ckecking
-- ---------------------------------------------------------

SELECT * FROM staging.ext_online_web_store LIMIT 5;
SELECT * FROM staging.ext_offline_legacy_erp LIMIT 5;
SELECT * FROM staging.stg_online_web_store LIMIT 10;
SELECT * FROM staging.stg_offline_legacy_erp LIMIT 10;
