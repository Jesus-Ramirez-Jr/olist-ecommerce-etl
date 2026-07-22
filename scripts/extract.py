import glob
import logging
from pathlib import Path
from dotenv import load_dotenv
import kagglehub
from google.api_core import exceptions as gcloud_exceptions
from google.cloud import bigquery
from google.cloud import storage
import os
import csv

# Configure structured logging
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(name)s: %(message)s",
    datefmt="%Y-%m-%d %H:%M:%S"
)
logger = logging.getLogger("olist_etl_pipeline")

# Load environment variables from the .env file
load_dotenv()
EXPECTED_CSV_COUNT = 9
GCS_BUCKET_NAME = "olist-ecommerce-etl-landingzone"
BQ_DATASET_ID = "olist_ecommerce_raw"

TABLE_MAPPING = {
    "olist_customers_dataset.csv": "customers",
    "olist_geolocation_dataset.csv": "geolocation",
    "olist_order_items_dataset.csv": "order_items",
    "olist_order_payments_dataset.csv": "order_payments",
    "olist_order_reviews_dataset.csv": "order_reviews",
    "olist_orders_dataset.csv": "orders",
    "olist_products_dataset.csv": "products",
    "olist_sellers_dataset.csv": "sellers",
    "product_category_name_translation.csv": "product_category_translation",
}


def authenticate_kaggle():
    """Authenticate to Kaggle using environment variables."""
    try:
        kagglehub.whoami()
        logger.info("Kaggle authentication successful.")
    except kagglehub.exceptions.UnauthenticatedError as e:
        logger.error(f"Authentication failed: {e}")
        raise


def download_dataset(dataset_handle: str) -> str:
    logger.info(f"Downloading dataset: {dataset_handle} via kagglehub...")
    path = kagglehub.dataset_download(dataset_handle)
    logger.info(f"Dataset downloaded successfully to: {path}")
    return path


def check_csv_count(path, expected_count):
    csv_files = glob.glob(f"{path}/*.csv")
    csv_count = len(csv_files)

    if csv_count != expected_count:
        logger.error(
            f"Validation failed. Expected {expected_count} CSVs, found {csv_count} in {path}")
        raise ValueError(
            f"Expected {expected_count} CSVs, found {csv_count} in {path}"
        )
    logger.info(f"CSV count verification passed: Found {csv_count} files.")


def upload_file_to_gcs(local_path: str, blob_name: str) -> str:
    """Upload a single local file to the GCS landing zone bucket. Returns the GCS URI."""
    client = storage.Client()
    bucket = client.bucket(GCS_BUCKET_NAME)
    blob = bucket.blob(blob_name)
    blob.upload_from_filename(local_path)

    gcs_uri = f"gs://{GCS_BUCKET_NAME}/{blob_name}"
    logger.info(f"Uploaded {blob_name} -> {gcs_uri}")
    return gcs_uri


def get_csv_data_row_count(local_path: str) -> int:
    """Accurately counts the data rows in a CSV file using Python's csv module.

    This handles multiline fields correctly and excludes the header row.
    Raises a ValueError immediately if the file is empty (missing headers),
    as this indicates a corrupted download.
    """
    with open(local_path, "r", encoding="utf-8", newline="") as f:
        reader = csv.reader(f)
        try:
            next(reader)  # Attempt to read and skip the header row
        except StopIteration:
            # Operational alert for log monitors
            logger.critical(
                "Pipeline execution aborted. A critical source file is corrupted or truncated, "
                "preventing safe schema parsing and data validation."
            )
            # Technical detail for the developer traceback
            raise ValueError(
                f"Empty or headerless CSV file detected at '{local_path}'. "
                "Unable to parse header row; stream ended unexpectedly (StopIteration)."
            )

        # Count the remaining data rows
        return sum(1 for _ in reader)


def load_gcs_to_bigquery(uri_list: list, dataset_id: str):
    """Loads GCS CSV URIs into explicitly mapped BigQuery tables."""
    client = bigquery.Client()

    job_config = bigquery.LoadJobConfig(
        source_format=bigquery.SourceFormat.CSV,
        skip_leading_rows=1,
        autodetect=True,
        write_disposition=bigquery.WriteDisposition.WRITE_TRUNCATE,
        allow_quoted_newlines=True,
    )

    for uri in uri_list:
        filename = uri.split("/")[-1]
        table_name = TABLE_MAPPING.get(filename)

        if not table_name:
            logger.critical(
                f"Unmapped file detected: '{filename}'. Aborting execution to prevent data omission.")
            raise ValueError(
                f"Unmapped file detected: '{filename}'. Pipeline halted to prevent data omission."
            )

        table_id = f"{client.project}.{dataset_id}.{table_name}"

        try:
            logger.info(
                f"Starting BigQuery load job: {filename} -> {table_id}")
            job = client.load_table_from_uri(
                uri, table_id, job_config=job_config
            )
            job.result()
            logger.info(
                f"Successfully loaded {job.output_rows} rows into {table_id}.")
        except gcloud_exceptions.GoogleAPICallError as e:
            logger.error(
                f"Google API Error occurred while loading {uri} to {table_id}: {e}")
            raise


def verify_row_counts_batch(local_dir_path: str, dataset_id: str):
    """Verifies all tables by counting local CSVs, fetching BQ row counts,
    and reporting all mismatches together at the end.

    If any local CSV is completely empty, its ValueError propagates immediately,
    halting the pipeline before BigQuery metadata queries are made.
    """
    logger.info("Starting batch data verification step...")
    client = bigquery.Client()
    mismatches = []

    # Loop over the 9 mapped tables using the single source of truth: TABLE_MAPPING
    for filename, table_name in TABLE_MAPPING.items():
        # Construct the full local path to the CSV file
        local_file_path = os.path.join(local_dir_path, filename)

        # 1. Get local CSV row count. If a file is completely empty/headerless,
        # this raises a ValueError and halts the pipeline immediately.
        logger.info(f"Parsing local CSV structure for row count: {filename}")
        expected_count = get_csv_data_row_count(local_file_path)

        # Construct full BigQuery table path
        table_id = f"{client.project}.{dataset_id}.{table_name}"

        try:
            # 2. Get the BigQuery table row count via metadata (fast and free)
            table = client.get_table(table_id)
            bq_count = table.num_rows

            # 3. Collect mismatches instead of raising immediately
            if bq_count != expected_count:
                logger.error(
                    f"Mismatch found for '{table_name}'! "
                    f"Local CSV: {expected_count} rows | BigQuery: {bq_count} rows"
                )
                mismatches.append({
                    "table": table_name,
                    "expected": expected_count,
                    "actual": bq_count
                })
            else:
                logger.info(
                    f"Verification passed for '{table_name}': {bq_count} rows match perfectly.")

        except gcloud_exceptions.GoogleAPICallError as e:
            logger.error(
                f"Failed to fetch metadata for BigQuery table {table_id}: {e}")
            raise

    # 4. Fail loud with all mismatches reported together if any exist
    if mismatches:
        # Build a clean, structured summary for the error message
        summary_lines = [
            f"  - Table '{m['table']}': Expected {m['expected']} rows, got {m['actual']} rows"
            for m in mismatches
        ]
        summary_report = "\n".join(summary_lines)

        logger.critical(
            f"Data verification failed! {len(mismatches)} table(s) had mismatched row counts.\n{summary_report}"
        )
        raise ValueError(
            f"Row count validation failed for the following tables:\n{summary_report}\n"
            "Pipeline halted to prevent downstream issues."
        )

    logger.info(
        "All tables verified successfully. No row count mismatches found!")


def main():
    """Start and orchestrate the script in order."""
    logger.info("Starting Olist ETL Pipeline.")
    authenticate_kaggle()
    path = download_dataset("olistbr/brazilian-ecommerce")
    check_csv_count(path, EXPECTED_CSV_COUNT)

    csv_files = glob.glob(f"{path}/*.csv")
    uri_list = []
    for file in csv_files:
        filename = Path(file).name
        uri = upload_file_to_gcs(file, filename)
        uri_list.append(uri)

    logger.info(
        "All files successfully staged in GCS. Proceeding to BigQuery ingestion.")
    load_gcs_to_bigquery(uri_list, BQ_DATASET_ID)

    verify_row_counts_batch(path, BQ_DATASET_ID)

    logger.info("Olist ETL Pipeline completed successfully!")


if __name__ == "__main__":
    main()
