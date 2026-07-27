"""
ETL pipeline: online-web-store + offline-legacy-erp -> retail DWH (star schema)

"""

import argparse
import os

import pandas as pd
from sqlalchemy import create_engine, text



def get_engine(args):
    host = args.host or os.environ.get("PGHOST", "localhost")
    port = args.port or os.environ.get("PGPORT", "5432")
    dbname = args.dbname or os.environ.get("PGDATABASE", "retail_dwh")
    user = args.user or os.environ.get("PGUSER", "postgres")
    password = args.password or os.environ.get("PGPASSWORD", "")
    url = f"postgresql+psycopg2://{user}:{password}@{host}:{port}/{dbname}"
    return create_engine(url)



def parse_date(series: pd.Series) -> pd.Series:
    return pd.to_datetime(series, format="%d.%m.%Y", errors="coerce")


def parse_money(series: pd.Series) -> pd.Series:
    return (
        series.astype(str)
        .str.replace("$", "", regex=False)
        .str.replace(" ", "", regex=False)
        .str.replace(",", ".", regex=False)
        .replace({"nan": None, "": None})
        .astype(float)
    )




def load_staging(engine) -> tuple[pd.DataFrame, pd.DataFrame]:
    online = pd.read_sql("SELECT * FROM staging.stg_online_web_store", engine)
    offline = pd.read_sql("SELECT * FROM staging.stg_offline_legacy_erp", engine)

    for df, channel in ((online, "Online"), (offline, "Offline")):
        df["order_date"] = parse_date(df["order_date"])
        df["ship_date"] = parse_date(df["ship_date"])
        df["sales"] = parse_money(df["sales"])
        df["profit"] = parse_money(df["profit"])
        df["shipping_cost"] = parse_money(df["shipping_cost"])
        df["discount"] = pd.to_numeric(df["discount"].astype(str).str.replace(",", "."), errors="coerce")
        df["quantity"] = pd.to_numeric(df["quantity"], errors="coerce").astype("Int64")
        df["channel"] = channel

    return online, offline




def build_dim_date(all_dates: pd.Series) -> pd.DataFrame:
    dates = pd.to_datetime(all_dates.dropna().unique())
    dim = pd.DataFrame({"full_date": dates})
    dim["date_id"] = dim["full_date"].dt.strftime("%Y%m%d").astype(int)
    dim["day"] = dim["full_date"].dt.day
    dim["month"] = dim["full_date"].dt.month
    dim["month_name"] = dim["full_date"].dt.strftime("%B")
    dim["quarter"] = dim["full_date"].dt.quarter
    dim["year"] = dim["full_date"].dt.year
    return dim.sort_values("date_id").reset_index(drop=True)


def build_dim_product(combined: pd.DataFrame) -> pd.DataFrame:
    dim = (
        combined[["product_id", "product_name", "sub_category", "category", "product_supplier"]]
        .drop_duplicates("product_id")
        .rename(columns={"sub_category": "subcategory_name", "category": "category_name"})
        .reset_index(drop=True)
    )
    dim.insert(0, "product_surr_id", dim.index + 1)
    return dim


def build_dim_customer(combined: pd.DataFrame) -> pd.DataFrame:
    dim = combined[["customer_id", "customer_first_name", "customer_last_name", "customer_segment"]].drop_duplicates("customer_id")
    dim["customer_name"] = dim["customer_first_name"].fillna("") + " " + dim["customer_last_name"].fillna("")
    dim = dim.rename(columns={"customer_segment": "segment"})[["customer_id", "customer_name", "segment"]].reset_index(drop=True)
    dim.insert(0, "customer_surr_id", dim.index + 1)
    return dim


def build_dim_geography(combined: pd.DataFrame) -> pd.DataFrame:
    cols = ["geo_market", "geo_region", "geo_country", "geo_state", "geo_city", "geo_postalcode"]
    dim = combined[cols].drop_duplicates().reset_index(drop=True)
    dim = dim.rename(columns={
        "geo_market": "market", "geo_region": "region", "geo_country": "country",
        "geo_state": "state", "geo_city": "city", "geo_postalcode": "postal_code",
    })
    dim.insert(0, "geography_id", dim.index + 1)
    return dim


def build_dim_store(offline: pd.DataFrame) -> pd.DataFrame:
    dim = offline[["store_id", "store_address", "store_type", "store_phone"]].drop_duplicates("store_id")
    return dim.reset_index(drop=True)


def build_dim_cashier(offline: pd.DataFrame) -> pd.DataFrame:
    dim = offline[["cashier_id", "cashier_first_name", "cashier_last_name", "cashier_email", "cashier_phone"]].drop_duplicates("cashier_id")
    dim = dim.rename(columns={"cashier_first_name": "first_name", "cashier_last_name": "last_name",
                               "cashier_email": "email", "cashier_phone": "phone"})
    return dim.reset_index(drop=True)


def build_fact_sales(combined: pd.DataFrame, dim_geo: pd.DataFrame, dim_product: pd.DataFrame, dim_customer: pd.DataFrame) -> pd.DataFrame:
    geo_key_cols = ["geo_market", "geo_region", "geo_country", "geo_state", "geo_city", "geo_postalcode"]
    dim_geo_keys = dim_geo.rename(columns={
        "market": "geo_market", "region": "geo_region", "country": "geo_country",
        "state": "geo_state", "city": "geo_city", "postal_code": "geo_postalcode",
    })
    merged = combined.merge(dim_geo_keys[geo_key_cols + ["geography_id"]], on=geo_key_cols, how="left")
    merged = merged.merge(dim_product[["product_id", "product_surr_id"]], on="product_id", how="left")
    merged = merged.merge(dim_customer[["customer_id", "customer_surr_id"]], on="customer_id", how="left")

    fact = pd.DataFrame({
        "order_id": merged["order_id"],
        "date_id": merged["order_date"].dt.strftime("%Y%m%d").astype("Int64"),
        "customer_surr_id": merged["customer_surr_id"],
        "product_surr_id": merged["product_surr_id"],
        "geography_id": merged["geography_id"],
        "store_id": merged.get("store_id"),
        "cashier_id": merged.get("cashier_id"),
        "channel": merged["channel"],
        "quantity": merged["quantity"],
        "sales_amount": merged["sales"],
        "discount": merged["discount"],
        "profit": merged["profit"],
        "shipping_cost": merged["shipping_cost"],
    })
    fact = fact.dropna(subset=["date_id", "customer_surr_id", "product_surr_id", "geography_id"])
    fact.insert(0, "sales_id", range(1, len(fact) + 1))
    return fact



def load_dimensional(engine, dim_date, dim_product, dim_customer, dim_geo, dim_store, dim_cashier, fact_sales):
    with engine.begin() as conn:
        
        conn.execute(text("TRUNCATE TABLE dm.fct_sales, dm.dim_date, dm.dim_product, "
                           "dm.dim_customer, dm.dim_geography, dm.dim_store, dm.dim_cashier "
                           "RESTART IDENTITY CASCADE"))

    dim_date.to_sql("dim_date", engine, schema="dm", if_exists="append", index=False)
    dim_product.to_sql("dim_product", engine, schema="dm", if_exists="append", index=False)
    dim_customer.to_sql("dim_customer", engine, schema="dm", if_exists="append", index=False)
    dim_geo.to_sql("dim_geography", engine, schema="dm", if_exists="append", index=False)
    dim_store.to_sql("dim_store", engine, schema="dm", if_exists="append", index=False)
    dim_cashier.to_sql("dim_cashier", engine, schema="dm", if_exists="append", index=False)
    fact_sales.to_sql("fct_sales", engine, schema="dm", if_exists="append", index=False, chunksize=10000)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--host")
    parser.add_argument("--port")
    parser.add_argument("--dbname")
    parser.add_argument("--user")
    parser.add_argument("--password")
    args = parser.parse_args()

    engine = get_engine(args)

    print("Reading staging tables from Postgres...")
    online, offline = load_staging(engine)
    combined = pd.concat([online, offline], ignore_index=True, sort=False)
    print(f"  online: {len(online):,} | offline: {len(offline):,} | combined: {len(combined):,}")

    print("Building dimensions...")
    dim_date = build_dim_date(combined["order_date"])
    dim_product = build_dim_product(combined)
    dim_customer = build_dim_customer(combined)
    dim_geo = build_dim_geography(combined)
    dim_store = build_dim_store(offline)
    dim_cashier = build_dim_cashier(offline)

    print("Building fact table...")
    fact_sales = build_fact_sales(combined, dim_geo, dim_product, dim_customer)

    print("Loading dm schema in Postgres...")
    load_dimensional(engine, dim_date, dim_product, dim_customer, dim_geo, dim_store, dim_cashier, fact_sales)

    print("Done. Row counts loaded into dm.*:")
    print(f"  dim_date:      {len(dim_date):,}")
    print(f"  dim_product:   {len(dim_product):,}")
    print(f"  dim_customer:  {len(dim_customer):,}")
    print(f"  dim_geography: {len(dim_geo):,}")
    print(f"  dim_store:     {len(dim_store):,}")
    print(f"  dim_cashier:   {len(dim_cashier):,}")
    print(f"  fct_sales:     {len(fact_sales):,}")


if __name__ == "__main__":
    main()


