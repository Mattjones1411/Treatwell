import requests
import json
import boto3
import logging
from datetime import date
from concurrent.futures import ThreadPoolExecutor

# Configure logging
logging.basicConfig(level=logging.INFO, format="%(asctime)s - %(levelname)s - %(message)s")

# Use a single session for all requests
session = requests.Session()

def extract_countries():
    """Fetch all countries' data from the API."""
    url = "https://restcountries.com/v3.1/all"
    try:
        response = session.get(url, timeout=10)
        response.raise_for_status()  # Raise an error for bad status codes
        return response.json()
    except requests.RequestException as e:
        logging.error(f"Failed to fetch countries: {e}")
        return []

def extract_translation(translation):
    """Fetch country translation from API."""
    url = f"https://restcountries.com/v3.1/translation/{translation}"
    try:
        response = session.get(url, timeout=10)
        response.raise_for_status()
        return response.json()
    except requests.RequestException as e:
        logging.warning(f"Failed to fetch translation for '{translation}': {e}")
        return None  # Return None to indicate failure

def save_to_s3(bucket, file_path, dataset):
    """Save JSON data to S3."""
    try:
        s3_client = boto3.client("s3")
        s3_client.put_object(
            Body=json.dumps(dataset, indent=4),
            Bucket=bucket,
            Key=file_path,
            ContentType="application/json"
        )
        logging.info(f"File saved to s3://{bucket}/{file_path}")
    except boto3.exceptions.Boto3Error as e:
        logging.error(f"Failed to upload to S3: {e}")

def fetch_translations(countries):
    """Fetch translations in parallel using ThreadPoolExecutor."""
    translations_dataset = []
    with ThreadPoolExecutor(max_workers=10) as executor:
        # Extract first known translation name and fetch data concurrently
        futures = {executor.submit(extract_translation, next(iter(c['translations'].values()))['official']): c for c in countries}
        
        for future in futures:
            translation = future.result()
            if translation:  # Only add successful translations
                translations_dataset.append(translation)
    
    return translations_dataset

def run():
    """Main function to orchestrate the process."""
    countries_dataset = extract_countries()
    if not countries_dataset:
        logging.error("No countries data fetched.")
        return

    translations_dataset = fetch_translations(countries_dataset)

    bucket_name = "countries_extraction"
    today = date.today().strftime("%Y-%m-%d")
    
    save_to_s3(bucket_name, f"countries/{today}/countries.json", countries_dataset)
    save_to_s3(bucket_name, f"countries/{today}/translations.json", translations_dataset)

if __name__ == "__main__":
    run()