"""
ETL pipeline: online-web-store + offline-legacy-erp -> retail DWH (star schema)


run:
    python etl_pipeline.py --offline path/to/offline_legacy_erp.csv \
                            --online  path/to/online_web_store.csv \
                            --out     ../output/retail_dwh.db
"""
import argparse
import sqlite3
import pandas as pd


def load_offline(path: str) -> pd.DataFrame:
    df = pd.read_csv(path, sep=";", encoding="utf-8-sig")
    df["Order_Date"] = pd.to_datetime(df["Order_Date"], format="%d.%m.%Y", errors="coerce")
    df["Ship_Date"] = pd.to_datetime(df["Ship_Date"], format="%d.%m.%Y", errors="coerce")
    for col in ["Sales", "Profit"]:
        df[col] = (
            df[col].astype(str).str.replace("$", "", regex=False)
            .str.replace(" ", "", regex=False).str.replace(",", ".", regex=False)
        ).astype(float)
    df["Shipping Cost"] = (
        df["Shipping Cost"].astype(str).str.replace(",", ".", regex=False)
    ).astype(float)
    df["Channel"] = "Offline"
    df["Device_Type"] = None
    df["Payment_Method"] = None
    return df


def load_online(path: str) -> pd.DataFrame:
    df = pd.read_csv(path, sep=";", encoding="utf-8-sig")
    df["Order Date"] = pd.to_datetime(df["Order Date"], format="%d.%m.%Y", errors="coerce")
    df["Ship Date"] = pd.to_datetime(df["Ship Date"], format="%d.%m.%Y", errors="coerce")
    for col in ["Sales", "Profit"]:
        df[col] = (
            df[col].astype(str).str.replace("$", "", regex=False)
            .str.replace(" ", "", regex=False).str.replace(",", ".", regex=False)
        ).astype(float)
    df["Shipping Cost"] = (
        df["Shipping Cost"].astype(str).str.replace(",", ".", regex=False)
    ).astype(float)
    # normalize column names to match offline schema for the shared merge step
    df = df.rename(columns={
        "Order Date": "Order_Date", "Ship Date": "Ship_Date",
        "Customer ID": "Customer_ID", "Customer First Name": "Customer_FirstName",
        "Customer Last Name": "Customer_LastName", "Customer Phone": "Customer_Phone",
        "Customer Segment": "Customer_Segment", "Geo PostalCode": "Geo_PostalCode",
        "Geo City": "Geo_City", "Geo State": "Geo_State", "Geo Country": "Geo_Country",
        "Geo Region": "Geo_Region", "Geo Market": "Geo_Market", "SubCategory": "Sub_Category",
        "Product Name": "Product_Name", "Product Supplier": "Product_Supplier",
    })
    return df


def build_dim_date(all_dates: pd.Series) -> pd.DataFrame:
    dates = pd.to_datetime(all_dates.dropna().unique())
    dim = pd.DataFrame({"Full_Date": dates})
    dim["Date_ID"] = dim["Full_Date"].dt.strftime("%Y%m%d").astype(int)
    dim["Day"] = dim["Full_Date"].dt.day
    dim["Month"] = dim["Full_Date"].dt.month
    dim["Month_Name"] = dim["Full_Date"].dt.strftime("%B")
    dim["Quarter"] = dim["Full_Date"].dt.quarter
    dim["Year"] = dim["Full_Date"].dt.year
    return dim.sort_values("Date_ID").reset_index(drop=True)


def build_dim_product(combined: pd.DataFrame) -> pd.DataFrame:
    dim = combined[["Product_ID", "Product_Name", "Sub_Category", "Category"]].drop_duplicates("Product_ID")
    return dim.reset_index(drop=True)


def build_dim_customer(combined: pd.DataFrame) -> pd.DataFrame:
    dim = combined[["Customer_ID", "Customer_FirstName", "Customer_LastName", "Customer_Segment"]].drop_duplicates("Customer_ID")
    dim["Customer_Name"] = dim["Customer_FirstName"].fillna("") + " " + dim["Customer_LastName"].fillna("")
    return dim[["Customer_ID", "Customer_Name", "Customer_Segment"]].reset_index(drop=True)


def build_dim_geography(combined: pd.DataFrame) -> pd.DataFrame:
    cols = ["Geo_Market", "Geo_Region", "Geo_Country", "Geo_State", "Geo_City", "Geo_PostalCode"]
    dim = combined[cols].drop_duplicates().reset_index(drop=True)
    dim.insert(0, "Geography_ID", dim.index + 1)
    return dim


def build_dim_store(offline: pd.DataFrame) -> pd.DataFrame:
    dim = offline[["Store_ID", "Store_Address", "Store_Type", "Store_phone"]].drop_duplicates("Store_ID")
    return dim.reset_index(drop=True)


def build_dim_cashier(offline: pd.DataFrame) -> pd.DataFrame:
    dim = offline[["Cashier_ID", "Cashier_FirstNname", "Cashier_LastNname", "Cashier_Email", "Cashier_phone"]].drop_duplicates("Cashier_ID")
    dim = dim.rename(columns={"Cashier_FirstNname": "First_Name", "Cashier_LastNname": "Last_Name"})
    return dim.reset_index(drop=True)


def build_fact_sales(combined: pd.DataFrame, dim_geo: pd.DataFrame) -> pd.DataFrame:
    geo_key_cols = ["Geo_Market", "Geo_Region", "Geo_Country", "Geo_State", "Geo_City", "Geo_PostalCode"]
    merged = combined.merge(dim_geo, on=geo_key_cols, how="left")
    fact = pd.DataFrame({
        "Order_ID": merged["Order_ID"],
        "Date_ID": merged["Order_Date"].dt.strftime("%Y%m%d").astype("Int64"),
        "Customer_ID": merged["Customer_ID"],
        "Product_ID": merged["Product_ID"],
        "Geography_ID": merged["Geography_ID"],
        "Store_ID": merged.get("Store_ID"),
        "Cashier_ID": merged.get("Cashier_ID"),
        "Channel": merged["Channel"],
        "Quantity": merged["Quantity"],
        "Sales_Amount": merged["Sales"],
        "Discount": merged["Discount"],
        "Profit": merged["Profit"],
        "Shipping_Cost": merged["Shipping Cost"],
    })
    fact["Total_Cost"] = fact["Shipping_Cost"] + (fact["Sales_Amount"] - fact["Profit"])
    fact.insert(0, "Sales_ID", range(1, len(fact) + 1))
    return fact


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--offline", required=True)
    parser.add_argument("--online", required=True)
    parser.add_argument("--out", required=True)
    args = parser.parse_args()

    print("Loading source files...")
    offline = load_offline(args.offline)
    online = load_online(args.online)
    combined = pd.concat([offline, online], ignore_index=True, sort=False)
    print(f"  offline rows: {len(offline):,} | online rows: {len(online):,} | combined: {len(combined):,}")

    print("Building dimension tables...")
    dim_date = build_dim_date(combined["Order_Date"])
    dim_product = build_dim_product(combined)
    dim_customer = build_dim_customer(combined)
    dim_geo = build_dim_geography(combined)
    dim_store = build_dim_store(offline)
    dim_cashier = build_dim_cashier(offline)

    print("Building fact table...")
    fact_sales = build_fact_sales(combined, dim_geo)

    print(f"Writing to {args.out} ...")
    conn = sqlite3.connect(args.out)
    dim_date.to_sql("dim_date", conn, if_exists="replace", index=False)
    dim_product.to_sql("dim_product", conn, if_exists="replace", index=False)
    dim_customer.to_sql("dim_customer", conn, if_exists="replace", index=False)
    dim_geo.to_sql("dim_geography", conn, if_exists="replace", index=False)
    dim_store.to_sql("dim_store", conn, if_exists="replace", index=False)
    dim_cashier.to_sql("dim_cashier", conn, if_exists="replace", index=False)
    fact_sales.to_sql("fct_sales", conn, if_exists="replace", index=False)
    conn.close()

    print("Done. Row counts:")
    print(f"  dim_date:      {len(dim_date):,}")
    print(f"  dim_product:   {len(dim_product):,}")
    print(f"  dim_customer:  {len(dim_customer):,}")
    print(f"  dim_geography: {len(dim_geo):,}")
    print(f"  dim_store:     {len(dim_store):,}")
    print(f"  dim_cashier:   {len(dim_cashier):,}")
    print(f"  fct_sales:     {len(fact_sales):,}")


if __name__ == "__main__":
    main()
