-- ============================================================
-- DIMENSIONAL LAYER (star schema)
-- ============================================================

CREATE TABLE dm.dim_date (
    date_id     INT PRIMARY KEY,     -- surrogate key, format YYYYMMDD
    full_date   DATE NOT NULL,
    day         INT NOT NULL,
    month       INT NOT NULL,
    month_name  VARCHAR(20) NOT NULL,
    quarter     INT NOT NULL,
    year        INT NOT NULL
);

CREATE TABLE dm.dim_product (
    product_surr_id  BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    product_id       VARCHAR(50) NOT NULL,   -- natural key
    product_name     VARCHAR(255),
    subcategory_name VARCHAR(100),
    category_name    VARCHAR(100),
    product_supplier VARCHAR(150)
);

CREATE TABLE dm.dim_customer (
    customer_surr_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    customer_id      VARCHAR(50) NOT NULL,
    customer_name    VARCHAR(200),
    segment          VARCHAR(50)
);

CREATE TABLE dm.dim_geography (
    geography_id  BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    market        VARCHAR(100),
    region        VARCHAR(100),
    country       VARCHAR(100),
    state         VARCHAR(100),
    city          VARCHAR(100),
    postal_code   VARCHAR(20)
);

CREATE TABLE dm.dim_store (
    store_id      VARCHAR(50) PRIMARY KEY,
    store_address VARCHAR(200),
    store_type    VARCHAR(50),
    store_phone   VARCHAR(50)
);

CREATE TABLE dm.dim_cashier (
    cashier_id VARCHAR(50) PRIMARY KEY,
    first_name VARCHAR(100),
    last_name  VARCHAR(100),
    email      VARCHAR(150),
    phone      VARCHAR(50)
);

-- Fact table
CREATE TABLE dm.fct_sales (
    sales_id       BIGINT GENERATED ALWAYS AS IDENTITY,
    order_id       VARCHAR(50) NOT NULL,
    date_id        INT NOT NULL REFERENCES dm.dim_date(date_id),
    customer_surr_id BIGINT NOT NULL REFERENCES dm.dim_customer(customer_surr_id),
    product_surr_id  BIGINT NOT NULL REFERENCES dm.dim_product(product_surr_id),
    geography_id   BIGINT NOT NULL REFERENCES dm.dim_geography(geography_id),
    store_id       VARCHAR(50) REFERENCES dm.dim_store(store_id),      -- NULL for online-orders
    cashier_id     VARCHAR(50) REFERENCES dm.dim_cashier(cashier_id),  -- NULL for online-orders
    channel        VARCHAR(20) NOT NULL,     -- Online / Offline
    quantity       INT NOT NULL,
    sales_amount   NUMERIC(12,2) NOT NULL,
    discount       NUMERIC(5,2) DEFAULT 0,
    profit         NUMERIC(12,2),
    shipping_cost  NUMERIC(10,2),
    total_cost     NUMERIC(12,2) GENERATED ALWAYS AS (shipping_cost + (sales_amount - profit)) STORED,
    PRIMARY KEY (sales_id, date_id)      -- date_id as PK 
) PARTITION BY RANGE (date_id);
