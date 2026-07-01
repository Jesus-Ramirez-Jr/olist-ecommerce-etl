# E-Commerce ETL & Analytics Pipeline

## 🎯 Project Objective
Build a scalable, end-to-end data pipeline that extracts a public e-commerce dataset
via the Kaggle API, orchestrates the data flow into GCP, and transforms it using dbt.
Final models will empower analysts to perform deep-dive analytics on customer retention,
product performance, and regional revenue.

---

## 📈 Core Business Questions

### Customer Retention & Loyalty
- What is our repeat purchase rate and average time between orders?
- Which "gateway" products are most likely to convert a one-time buyer into a repeat customer?
- What specific products or categories do repeat customers purchase most frequently?
- What is our Customer Lifetime Value (CLV) across different customer cohorts?

### Product & Vendor Performance
- Which sellers supply our highest and lowest performing products?
- Which product categories have the lowest customer review scores?

### Geography & Revenue
- Where are our highest-revenue regions geographically?

---

## 🏗️ Architecture Flow
1. Python script authenticates with Kaggle API and extracts raw CSVs
2. Raw CSVs uploaded to GCS bucket (raw landing zone)
3. Data loaded from GCS into BigQuery as raw, immutable tables
4. dbt Staging — standardize, rename, cast
5. dbt Intermediate — joins, business logic, reusable components
6. dbt Marts — final analytics-ready tables for analysts

---

## 🛠️ Tech Stack
- Language: Python, SQL
- Ingestion: Kaggle API
- Cloud: Google Cloud Storage, Google BigQuery
- Transformation: dbt

---

## ☁️ GCP Infrastructure (Provisioned)

| Resource | Value |
|---|---|
| Project Name | `olist-ecommerce-etl` |
| Project ID (auto-generated, ≠ name) | `project-dfa4f4f5-3dca-462a-bfe` |
| GCS Bucket | `olist-ecommerce-etl-landingzone` (us-west1, Standard storage, public access prevented, 7-day soft delete) |
| BigQuery Dataset | `olist_ecommerce_raw` (us-west1) |
| Service Account | `olist-etl-pipeline@project-dfa4f4f5-3dca-462a-bfe.iam.gserviceaccount.com` |
| Service Account IAM Roles | `roles/bigquery.jobUser` (project-level), `roles/storage.objectUser` (bucket-level), `roles/bigquery.dataEditor` (dataset-level) |

**Note:** Project *name* and *ID* differ — always use the ID (`project-dfa4f4f5-3dca-462a-bfe`) in `gcloud` commands, not the display name.

---

## 🔐 Credential Strategy (Finalized)

**Method: Application Default Credentials (ADC) with service account impersonation — no downloadable JSON key.**

Originally planned to use a JSON key file, but GCP org policy (`iam.disableServiceAccountKeyCreation`) blocked key creation. After evaluating tradeoffs, ADC + impersonation was confirmed as the better practice regardless — no long-lived key file, nothing to leak on a public repo.

Setup completed:
- `gcloud` CLI installed (Homebrew)
- `gcloud init` run, authenticated as personal account (`jrsemails5@gmail.com`), correct project selected
- Granted `roles/iam.serviceAccountTokenCreator` to `jrsemails5@gmail.com`, scoped to the `olist-etl-pipeline` service account only (not project-wide, not Service Account Admin)
- Ran: `gcloud auth application-default login --impersonate-service-account=olist-etl-pipeline@project-dfa4f4f5-3dca-462a-bfe.iam.gserviceaccount.com`
- Verified with `gcloud auth application-default print-access-token` — working

`credentials/` folder remains **empty** (no JSON key needed). `.gitignore` still excludes `credentials/` and `.env` as a safety net for any future secrets.

---

## 📁 Local Project Structure

```
olist-ecommerce-etl/
├── credentials/       # gitignored, currently empty (ADC used instead of key file)
├── scripts/            # extraction/upload/load Python scripts (chosen over src/)
├── .env
├── .gitignore
└── project_memory.md
```

---

## 🏁 Current Milestone: Milestone 1 — Data Ingestion

**Goal:** Successfully land all nine raw Olist tables in BigQuery via an automated
Python script using GCS as the intermediate landing zone.

### Task Checklist
- [x] Set up GCP project and enable BigQuery and Cloud Storage APIs
- [x] Create GCS bucket for raw data landing zone
- [x] Create BigQuery dataset for raw tables
- [x] Set up credential strategy (ADC + service account impersonation, verified working)
- [ ] Initialize git repo, push initial scaffolding to GitHub (public: `olist-ecommerce-etl`)
- [ ] Authenticate with Kaggle API securely using environment variables
- [ ] Write Python script to extract all nine CSVs from Kaggle API
- [ ] Write Python function to upload extracted CSVs to GCS bucket
- [ ] Write Python function to load CSVs from GCS into BigQuery raw tables
- [ ] Verify all nine tables present in BigQuery with correct row counts

### ✅ Definition of Done
Milestone 1 is complete when:
- All nine Olist tables exist in BigQuery raw dataset
- Row counts in BigQuery match source CSV row counts
- Script runs end-to-end without manual intervention
- No credentials are hardcoded anywhere in the codebase

---

## 🔜 Exact Next Steps

1. Run `git init` in the project folder (previously planned but not yet executed)
2. Verify `git status` shows `credentials/` and `.env` properly ignored
3. `git add .` → verify staged files → commit initial scaffolding
4. Create GitHub repo via VS Code's "Publish to GitHub" command (public, name `olist-ecommerce-etl`)
5. Kaggle API authentication (env-var based, same credential hygiene as GCP)
6. Write Python extraction script for all 9 Olist CSVs
7. Write GCS upload function
8. Write GCS → BigQuery load function
9. Row count verification to close out Milestone 1

---

## 👤 Mentee Profile

- Background: Data Analyst transitioning to Data Engineer
- Python level: Beginner/intermediate
- No prior dbt experience; now has hands-on GCP infra experience (billing, IAM, GCS, BigQuery dataset provisioning, ADC/impersonation)
- Has completed two prior projects: Google Sheets → MySQL pipeline, and pybaseball incremental loading pipeline
- Known pattern: tends to skip parts of multi-part tasks when uncomfortable — specifically execution of *planned* technical steps (e.g. correctly reasoned through `git init` sequencing, then didn't run it). Self-corrects well once called out directly. Continue holding accountable to full task completion, not just correct reasoning.
