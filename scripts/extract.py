import kagglehub
from dotenv import load_dotenv
import glob
from google.cloud import storage
from pathlib import Path

# Load environment variables from the .env file
load_dotenv()
EXPECTED_CSV_COUNT = 9
GCS_BUCKET_NAME = "olist-ecommerce-etl-landingzone"


def authenticate_kaggle():
    """Authenticate to Kaggle using environment variables."""

    try:
        kagglehub.whoami()

    except kagglehub.exceptions.UnauthenticatedError as e:
        print(f"Authentication failed: {e}")
        raise


def download_dataset(dataset_handle: str) -> str:
    path = kagglehub.dataset_download(dataset_handle)
    return path


def check_csv_count(path, expected_count):
    csv_files = glob.glob(f"{path}/*.csv")
    csv_count = len(csv_files)

    if csv_count != expected_count:
        raise ValueError(
            f"Expected {expected_count} CSVs, found {csv_count} in {path}")


def upload_file_to_gcs(local_path: str, blob_name: str) -> str:
    """Upload a single local file to the GCS landing zone bucket. Returns the GCS URI."""

    # Corrected initialization
    client = storage.Client()
    bucket = client.bucket(GCS_BUCKET_NAME)

    # Define the blob (the target file path in GCS)
    blob = bucket.blob(blob_name)

    # Upload the file
    blob.upload_from_filename(local_path)

    # Construct and return the GCS URI (e.g., gs://my-bucket/data.csv)
    gcs_uri = f"gs://{GCS_BUCKET_NAME}/{blob_name}"
    return gcs_uri


def main():
    """Start and orchestrate the script in order."""
    authenticate_kaggle()
    path = download_dataset('olistbr/brazilian-ecommerce')
    check_csv_count(path, EXPECTED_CSV_COUNT)

    csv_files = glob.glob(f"{path}/*.csv")
    uri_list = []
    for file in csv_files:
        filename = Path(file).name  # Extracts just the filename
        uri = upload_file_to_gcs(file, filename)
        uri_list.append(uri)

    print(uri_list)


if __name__ == "__main__":
    main()
