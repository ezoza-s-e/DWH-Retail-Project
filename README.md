# Retail DWH Design — Online + Offline Sales

Launch:
``bash
cd etl
python etl_pipeline.py \
    --offline ../data/offline_legacy_erp.csv \
    --online  ../data/online_web_store.csv \
    --out     ../output/retail_dwh.db
```

> The repository contains only small samples of the original CSV files
> (`data/sample_*.csv', 300 lines each) — complete files weigh 100+ MB and do not
> suitable for a regular git repository. The pipeline is working out
> it's the same on both the sample and the full data.

##7. Repository Structure

```
retail-dwh-design/
├── README.md
├── Project Description.pdf
├── sql/
│   ├── 01_staging.sql
│   ├── 02_3nf.sql
│   ├── 03_dimensional.sql
│   └── 04_partitioning.sql
├── etl/
│   └── etl_pipeline.py
├── data/
│   ├── sample_offline_legacy_erp.csv
│   └── sample_online_web_store.csv
└── output/
    └── retail_dwh.db (generated when starting the pipeline)
``