# Olist E-Commerce ETL & Analytics Pipeline

An end-to-end ELT pipeline — Python extraction, Google Cloud Storage landing zone, BigQuery warehouse, dbt transformation and testing — built to answer six business questions against the Brazilian E-Commerce Public Dataset (Olist). Built as a portfolio project for a Data Analyst → Data Engineer transition, with an emphasis on empirically verified findings, permanent automated tests, and documented design decisions rather than just a working pipeline.

## Contents

- [Architecture](#architecture)
- [Tech Stack](#tech-stack)
- [Business Questions & Findings](#business-questions--findings)
- [Data Quality & Testing](#data-quality--testing)
- [Repository Structure](#repository-structure)
- [Setup & Usage](#setup--usage)
- [Scope Notes — What's Not Included, and Why](#scope-notes--whats-not-included-and-why)
- [Known Limitations](#known-limitations)
- [Data Source & License](#data-source--license)
- [Author](#author)

## Architecture

```
Kaggle (raw CSVs)
      │
      ▼
Python extraction script
      │
      ▼
Google Cloud Storage  (raw landing zone)
      │
      ▼
BigQuery — raw dataset
      │
      ▼
dbt staging models  (9 models — one per source table, cleaned/typed/renamed)
      │
      ▼
dbt mart models  (6 models — one per business question, tested + documented)
```

Each mart is built one at a time: designed, empirically verified against real query output, covered by permanent dbt tests, documented via `schema.yml` descriptions, and committed — before moving to the next.

## Tech Stack

- **Python** — extraction from the Kaggle source into the GCS landing zone
- **Google Cloud Storage** — raw landing zone
- **BigQuery** — data warehouse (raw + transformed datasets)
- **dbt-core 1.12.0 / dbt-bigquery 1.12.0** — staging and mart transformations, testing, documentation
- **dbt-labs/dbt_utils 1.4.1** — generic tests (`expression_is_true`, etc.)
- **GitHub** — version control

## Business Questions & Findings

Full methodology and detail for each question live in [`business_questions_findings.md`](./business_questions_findings.md). Summary below.

### Customer Retention & Loyalty

1. **What percentage of customers place more than one order, and how does that repeat rate vary by state?**
   Overall repeat rate: **3.12%** (2,997 of 96,096 customers). By state (1,000+ customers): 1.68% (Ceará, low outlier) to 3.43% (Rio de Janeiro).

2. **Among customers who reorder, how much time typically passes between their first and second order?**
   Median **27–28 days**; mean is pulled up to 79.99 days by a long tail out to 608 days. 30.9% of reorders happen same-day.

3. **Is there a relationship between a customer's first-order review score and whether they ever reorder?**
   No meaningful relationship — reorder rates sit in a tight 2.85%–3.22% band across all five review scores.

### Product & Vendor Performance

4. **Which product categories drive the most revenue, and does that ranking hold up by order volume instead?**
   Top categories are stable across both metrics; the ranking diverges in the middle of the pack, driven by price point per order (e.g. `computers`: high revenue rank, low volume rank).

5. **Do the highest-revenue sellers also have the best delivery and review performance, or is there a volume/quality tradeoff?**
   No meaningful tradeoff — `CORR(revenue, on_time_rate) = -0.023`, `CORR(revenue, review_score) = -0.046` across 1,238 qualifying sellers, both effectively zero.

6. **Is there a relationship between delivery time and review score, and does it hold across product categories?**
   Yes — overall correlation **-0.3285**, the strongest relationship found in this project. Holds directionally in all 63 categories with enough data to check (none flip positive), though strength varies (-0.15 to -0.62) by category.

## Data Quality & Testing

Every mart is covered by dbt tests (`not_null`, `unique`, `accepted_values`, and `dbt_utils` generic tests), and every finding was checked against real query output before being written up — a clean `dbt run` was treated as necessary, not sufficient. A few real issues caught during the build, as an example of that discipline in practice:

- **Review-submission fan-out:** `stg_order_reviews` had duplicate submissions for 547 orders, which would have silently inflated row counts in any mart joining to it directly. Fixed with a `ROW_NUMBER()`-based dedup (latest submission wins) before every join to reviews.
- **`accepted_values` type mismatch:** dbt's `accepted_values` test defaults to `quote: true`, which assumes a string column. Applied to the numeric `review_score` column, this threw a BigQuery type-mismatch error rather than a normal test failure — fixed with an explicit `quote: false`.
- **`RANK()` is not a uniqueness guarantee:** an early test incorrectly asserted uniqueness on a `RANK()`-derived column, which legitimately produces ties. `ROW_NUMBER()` is the right tool when row-level uniqueness is actually required.
- **Inclusion thresholds are chosen from the data, not picked as round numbers:** e.g. the 30-order-per-category floor in question 6 was set by checking category-count-vs-coverage tradeoffs at several candidate thresholds first, not assumed.

## Repository Structure

```
olist-ecommerce-etl/
├── olist_ecommerce_etl/          # dbt project — cd here before running dbt commands
│   ├── models/
│   │   ├── staging/               # 9 models, one per source table
│   │   └── marts/
│   │       ├── mart_customer_repeat_rate.sql          # question 1
│   │       ├── mart_time_between_orders.sql           # question 2
│   │       ├── mart_first_order_retention.sql         # question 3
│   │       ├── mart_category_revenue_and_volume.sql   # question 4
│   │       ├── mart_seller_performance.sql            # question 5
│   │       ├── mart_delivery_time_review_score.sql    # question 6
│   │       └── schema.yml                              # grain, descriptions, tests for all six marts
│   └── dbt_project.yml
├── scripts/
│   └── extract.py                # Kaggle → GCS extraction
├── business_questions_findings.md
└── README.md
```

## Setup & Usage

### Prerequisites

- Python 3.11+
- A GCP project with GCS and BigQuery enabled
- A GCP service account (or Application Default Credentials) with access to that project — **never hardcode credentials**; use ADC or a service account key referenced via an environment variable, not committed to the repo
- A Kaggle account and API token (for `scripts/extract.py` to pull the source dataset)
- `dbt-core` and `dbt-bigquery`

### Steps

```bash
# 1. Clone and set up the environment
git clone <this-repo-url>
cd olist-ecommerce-etl
python3.11 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt   # google-cloud-storage, google-cloud-bigquery, kaggle, etc.

# 2. Configure credentials (do not commit these)
export GOOGLE_APPLICATION_CREDENTIALS=<path-to-your-service-account-key>
# Kaggle API token expected at ~/.kaggle/kaggle.json

# 3. Extract source data and land it in GCS
python scripts/extract.py

# 4. Run the dbt project
cd olist_ecommerce_etl
dbt deps
dbt run
dbt test
dbt docs generate && dbt docs serve   # optional — browsable model docs
```

Adjust the `dbt_project.yml` / `profiles.yml` target (`dev`) and dataset (`olist_ecommerce_dbt`) to match your own GCP project.


## Data Source & License

[Brazilian E-Commerce Public Dataset by Olist](https://www.kaggle.com/datasets/olistbr/brazilian-ecommerce) — ~100,000 orders (2016–2018) with order, product, customer, seller, review, and geolocation data, published by Olist on Kaggle.


## Author

**Jesus Ramirez (Jr)** — Data Analyst transitioning to Data Engineering.
[LinkedIn](https://www.linkedin.com/in/jesus-s-ramirez-/) · [GitHub](https://github.com/Jesus-Ramirez-Jr) · [Email](jrsemails5@gmail.com)
