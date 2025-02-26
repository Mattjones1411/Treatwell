import pytest
import json
import boto3
from moto import mock_s3
from unittest.mock import patch, MagicMock
from data_extract import extract_countries, extract_translation, save_to_s3, fetch_translations

# Mocked API response for countries
MOCK_COUNTRIES = [
    {
        "name": {"common": "France"},
        "translations": {"fra": {"official": "France"}}
    },
    {
        "name": {"common": "Spain"},
        "translations": {"spa": {"official": "España"}}
    }
]

# Mocked API response for translations
MOCK_TRANSLATION = [
    {
        "name": {"common": "France"},
        "translations": {"fra": {"official": "France"}}
    }
]

@pytest.fixture
def mock_requests_get():
    """Mock the requests.get method"""
    with patch("requests.get") as mock_get:
        # Simulate API response for country extraction
        mock_get.side_effect = lambda url, **kwargs: MagicMock(
            status_code=200,
            json=lambda: MOCK_COUNTRIES if "all" in url else MOCK_TRANSLATION
        )
        yield mock_get

@mock_s3
def test_save_to_s3():
    """Test S3 upload functionality with mock S3"""
    bucket_name = "test-bucket"
    file_key = "test.json"
    data = {"message": "Hello, S3!"}

    # Mock S3
    s3 = boto3.client("s3", region_name="us-east-1")
    s3.create_bucket(Bucket=bucket_name)

    # Call function
    save_to_s3(bucket_name, file_key, data)

    # Verify file was uploaded
    response = s3.get_object(Bucket=bucket_name, Key=file_key)
    uploaded_data = json.loads(response["Body"].read().decode("utf-8"))
    
    assert uploaded_data == data

def test_extract_countries(mock_requests_get):
    """Test extraction of countries from API"""
    countries = extract_countries()
    assert len(countries) == 2  # We mocked 2 countries
    assert countries[0]["name"]["common"] == "France"

def test_extract_translation(mock_requests_get):
    """Test extraction of translations from API"""
    translation = extract_translation("France")
    assert translation is not None
    assert translation[0]["name"]["common"] == "France"

def test_fetch_translations(mock_requests_get):
    """Test fetching multiple translations concurrently"""
    translations = fetch_translations(MOCK_COUNTRIES)
    assert len(translations) == 1  # Mocked only one translation
    assert translations[0]["name"]["common"] == "France"