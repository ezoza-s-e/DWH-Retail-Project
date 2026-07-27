-- ============================================================
-- 3NF BUSINESS LAYER
-- ============================================================

CREATE TABLE core.ce_geo_markets (
    market_id     BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    market_name   VARCHAR(100) NOT NULL,
    source_system VARCHAR(50) NOT NULL,
    ta_insert_dt  TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE core.ce_geo_regions (
    region_id     BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    region_name   VARCHAR(100) NOT NULL,
    market_id     BIGINT NOT NULL REFERENCES core.ce_geo_markets(market_id),
    ta_insert_dt  TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE core.ce_geo_countries (
    country_id    BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    country_name  VARCHAR(100) NOT NULL,
    region_id     BIGINT NOT NULL REFERENCES core.ce_geo_regions(region_id),
    ta_insert_dt  TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE core.ce_geo_states (
    state_id      BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    state_name    VARCHAR(100) NOT NULL,
    country_id    BIGINT NOT NULL REFERENCES core.ce_geo_countries(country_id),
    ta_insert_dt  TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE core.ce_geo_cities (
    city_id       BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    city_name     VARCHAR(100) NOT NULL,
    state_id      BIGINT NOT NULL REFERENCES core.ce_geo_states(state_id),
    ta_insert_dt  TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE core.ce_geo_addresses (
    address_id    BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    postal_code   VARCHAR(20),
    city_id       BIGINT NOT NULL REFERENCES core.ce_geo_cities(city_id),
    ta_insert_dt  TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE core.ce_product_categories (
    category_id   BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    category_name VARCHAR(100) NOT NULL,
    source_system VARCHAR(50) NOT NULL,
    ta_insert_dt  TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE core.ce_product_subcategories (
    subcategory_id   BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    subcategory_name VARCHAR(100) NOT NULL,
    category_id      BIGINT NOT NULL REFERENCES core.ce_product_categories(category_id),
    ta_insert_dt     TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE core.ce_products (
    product_id       VARCHAR(50) PRIMARY KEY,
    product_name     VARCHAR(255) NOT NULL,
    product_supplier VARCHAR(150),
    subcategory_id   BIGINT NOT NULL REFERENCES core.ce_product_subcategories(subcategory_id),
    source_system    VARCHAR(50) NOT NULL,
    ta_insert_dt     TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    ta_update_dt     TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- SCD Type 2: stores the complete history of changes for the client
CREATE TABLE core.ce_customers_scd (
    customer_surr_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    customer_id      VARCHAR(50) NOT NULL,   -- natural key
    first_name       VARCHAR(100),
    last_name        VARCHAR(100),
    phone            VARCHAR(50),
    segment          VARCHAR(50),
    start_dt         DATE NOT NULL,
    end_dt           DATE,
    is_active        BOOLEAN NOT NULL DEFAULT TRUE,
    source_system    VARCHAR(50) NOT NULL,
    ta_insert_dt     TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE core.ce_stores (
    store_id      VARCHAR(50) PRIMARY KEY,
    store_type    VARCHAR(50),
    address_id    BIGINT REFERENCES core.ce_geo_addresses(address_id),
    store_phone   VARCHAR(50),
    source_system VARCHAR(50) NOT NULL,
    ta_insert_dt  TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE core.ce_cashiers (
    cashier_id    VARCHAR(50) PRIMARY KEY,
    first_name    VARCHAR(100),
    last_name     VARCHAR(100),
    email         VARCHAR(150),
    phone         VARCHAR(50),
    source_system VARCHAR(50) NOT NULL,
    ta_insert_dt  TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE core.ce_orders (
    order_id         VARCHAR(50) PRIMARY KEY,
    customer_surr_id BIGINT NOT NULL REFERENCES core.ce_customers_scd(customer_surr_id),
    order_date       DATE NOT NULL,
    ship_date        DATE,
    channel          VARCHAR(20) NOT NULL,   -- Online / Offline
    store_id         VARCHAR(50) REFERENCES core.ce_stores(store_id),        -- NULL for online
    cashier_id       VARCHAR(50) REFERENCES core.ce_cashiers(cashier_id),    -- NULL for online
    device_type      VARCHAR(30),            -- NULL for offline
    payment_method   VARCHAR(30),
    address_id       BIGINT REFERENCES core.ce_geo_addresses(address_id),
    source_system    VARCHAR(50) NOT NULL,
    ta_insert_dt     TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE core.ce_order_items (
    order_item_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    order_id      VARCHAR(50) NOT NULL REFERENCES core.ce_orders(order_id),
    product_id    VARCHAR(50) NOT NULL REFERENCES core.ce_products(product_id),
    quantity      INT NOT NULL,
    sales_amount  NUMERIC(12,2) NOT NULL,
    discount      NUMERIC(5,2) DEFAULT 0,
    profit        NUMERIC(12,2),
    shipping_cost NUMERIC(10,2),
    ta_insert_dt  TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
