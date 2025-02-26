import pytest
import json
import boto3
import requests
from datetime import date
from unittest.mock import patch, Mock

import country_extraction


@pytest.fixture
def sample_countries_data():
    """Fixture providing sample country data."""
    return [
        {
            "name": {"common": "Germany", "official": "Federal Republic of Germany"},
            "translations": {
                "fra": {
                    "official": "République fédérale d'Allemagne",
                    "common": "Allemagne",
                },
                "spa": {
                    "official": "República Federal de Alemania",
                    "common": "Alemania",
                },
            },
        },
        {
            "name": {"common": "France", "official": "French Republic"},
            "translations": {
                "deu": {"official": "Französische Republik", "common": "Frankreich"},
                "spa": {"official": "República Francesa", "common": "Francia"},
            },
        },
    ]


@pytest.fixture
def sample_translation_data():
    """Fixture providing sample translation data."""
    return [
        {
            "name": {"common": "Germany", "official": "Federal Republic of Germany"},
            "translations": {
                "fra": {
                    "official": "République fédérale d'Allemagne",
                    "common": "Allemagne",
                }
            },
        }
    ]


class TestExtractCountries:
    @patch("requests.Session.get")
    def test_successful_extraction(self, mock_get, sample_countries_data):
        """Test extraction of countries with successful API response."""
        # Setup mock response
        mock_response = Mock()
        mock_response.json.return_value = sample_countries_data
        mock_response.raise_for_status.return_value = None
        mock_get.return_value = mock_response

        # Call the function
        result = country_extraction.extract_countries()

        # Assertions
        mock_get.assert_called_once_with(
            "https://restcountries.com/v3.1/all", timeout=10
        )
        assert result == sample_countries_data

    @patch("requests.Session.get")
    def test_api_error(self, mock_get):
        """Test extraction with API error."""
        # Setup mock to raise exception
        mock_get.side_effect = requests.RequestException("API error")

        # Call function and verify empty list is returned
        result = country_extraction.extract_countries()
        assert result == []
        mock_get.assert_called_once()

    @patch("requests.Session.get")
    def test_http_error(self, mock_get):
        """Test extraction with HTTP error."""
        # Setup mock response with error status
        mock_response = Mock()
        mock_response.raise_for_status.side_effect = requests.HTTPError("404 Not Found")
        mock_get.return_value = mock_response

        # Call function and verify empty list is returned
        result = country_extraction.extract_countries()
        assert result == []
        mock_get.assert_called_once()


class TestExtractTranslation:
    @patch("requests.Session.get")
    def test_successful_translation_fetch(self, mock_get, sample_translation_data):
        """Test extraction of translation with successful API response."""
        # Setup mock response
        mock_response = Mock()
        mock_response.json.return_value = sample_translation_data
        mock_response.raise_for_status.return_value = None
        mock_get.return_value = mock_response

        # Call the function
        translation_term = "République fédérale d'Allemagne"
        result = country_extraction.extract_translation(translation_term)

        # Assertions
        expected_url = f"https://restcountries.com/v3.1/translation/{translation_term}"
        mock_get.assert_called_once_with(expected_url, timeout=10)
        assert result == sample_translation_data

    @patch("requests.Session.get")
    def test_translation_api_error(self, mock_get):
        """Test translation extraction with API error."""
        # Setup mock to raise exception
        mock_get.side_effect = requests.RequestException("API error")

        # Call function and verify None is returned
        result = country_extraction.extract_translation("test_translation")
        assert result is None
        mock_get.assert_called_once()


class TestSaveToS3:
    @patch("boto3.client")
    def test_successful_s3_upload(self, mock_boto_client):
        """Test successful upload to S3."""
        # Setup mock S3 client
        mock_s3 = Mock()
        mock_boto_client.return_value = mock_s3

        # Call the function
        bucket = "test-bucket"
        file_path = "test/path.json"
        data = {"test": "data"}
        country_extraction.save_to_s3(bucket, file_path, data)

        # Assertions
        mock_boto_client.assert_called_once_with("s3")
        mock_s3.put_object.assert_called_once_with(
            Body=json.dumps(data, indent=4),
            Bucket=bucket,
            Key=file_path,
            ContentType="application/json",
        )

    @patch("boto3.client")
    def test_s3_upload_error(self, mock_boto_client):
        """Test S3 upload with error."""
        # Setup mock to raise exception
        mock_s3 = Mock()
        mock_s3.put_object.side_effect = boto3.exceptions.Boto3Error("S3 error")
        mock_boto_client.return_value = mock_s3

        # Call function and verify it handles the exception
        bucket = "test-bucket"
        file_path = "test/path.json"
        data = {"test": "data"}
        # Should not raise exception
        country_extraction.save_to_s3(bucket, file_path, data)

        # Assert function called boto3 client
        mock_boto_client.assert_called_once_with("s3")
        mock_s3.put_object.assert_called_once()


class TestFetchTranslations:
    @patch("country_extraction.extract_translation")
    def test_fetch_translations(
        self, mock_extract_translation, sample_countries_data, sample_translation_data
    ):
        """Test fetching translations with ThreadPoolExecutor."""
        # Setup mock to return sample translation data
        mock_extract_translation.return_value = sample_translation_data[0]

        # Call the function
        result = country_extraction.fetch_translations(sample_countries_data)

        # Assertions
        assert len(result) == len(sample_countries_data)
        assert result[0] == sample_translation_data[0]

        # Check mock was called for each country
        assert mock_extract_translation.call_count == len(sample_countries_data)

    @patch("country_extraction.extract_translation")
    def test_fetch_translations_with_failures(
        self, mock_extract_translation, sample_countries_data
    ):
        """Test fetching translations with some failures."""

        # Setup mock to alternate between success and failure
        def side_effect(translation):
            if translation == "République fédérale d'Allemagne":
                return sample_countries_data[0]
            return None

        mock_extract_translation.side_effect = side_effect

        # Call the function
        result = country_extraction.fetch_translations(sample_countries_data)

        # Only successful translations should be included
        successful_count = sum(
            1
            for c in sample_countries_data
            if next(iter(c["translations"].values()))["official"]
            == "République fédérale d'Allemagne"
        )
        assert len(result) == successful_count


class TestRun:
    @patch("country_extraction.extract_countries")
    @patch("country_extraction.fetch_translations")
    @patch("country_extraction.save_to_s3")
    def test_successful_run(
        self,
        mock_save_to_s3,
        mock_fetch_translations,
        mock_extract_countries,
        sample_countries_data,
        sample_translation_data,
    ):
        """Test successful execution of the main run function."""
        # Setup mocks
        mock_extract_countries.return_value = sample_countries_data
        mock_fetch_translations.return_value = sample_translation_data

        # Call the function
        country_extraction.run()

        # Assertions
        mock_extract_countries.assert_called_once()
        mock_fetch_translations.assert_called_once_with(sample_countries_data)

        # Verify save_to_s3 was called twice with correct arguments
        today = date.today().strftime("%Y-%m-%d")
        bucket_name = "countries_extraction"

        assert mock_save_to_s3.call_count == 2
        mock_save_to_s3.assert_any_call(
            bucket_name, f"countries/{today}/countries.json", sample_countries_data
        )
        mock_save_to_s3.assert_any_call(
            bucket_name, f"countries/{today}/translations.json", sample_translation_data
        )

    @patch("country_extraction.extract_countries")
    @patch("country_extraction.fetch_translations")
    @patch("country_extraction.save_to_s3")
    def test_run_with_no_countries(
        self, mock_save_to_s3, mock_fetch_translations, mock_extract_countries
    ):
        """Test run function when no countries are fetched."""
        # Setup mock to return empty list
        mock_extract_countries.return_value = []

        # Call the function
        country_extraction.run()

        # Verify fetch_translations and save_to_s3 were not called
        mock_extract_countries.assert_called_once()
        mock_fetch_translations.assert_not_called()
        mock_save_to_s3.assert_not_called()


@pytest.mark.parametrize(
    "countries_data,expected_calls",
    [
        # Test with empty list
        ([], 0),
        # Test with one country
        (
            [
                {
                    "name": {"common": "Germany"},
                    "translations": {"fra": {"official": "Test"}},
                }
            ],
            1,
        ),
        # Test with multiple countries
        (
            [
                {
                    "name": {"common": "Germany"},
                    "translations": {"fra": {"official": "Test1"}},
                },
                {
                    "name": {"common": "France"},
                    "translations": {"fra": {"official": "Test2"}},
                },
                {
                    "name": {"common": "Spain"},
                    "translations": {"fra": {"official": "Test3"}},
                },
            ],
            3,
        ),
    ],
)
def test_fetch_translations_parametrized(countries_data, expected_calls):
    """Parametrized test for fetch_translations with different data sizes."""
    with patch(
        "country_extraction.extract_translation", return_value={"test": "data"}
    ) as mock_extract:
        result = country_extraction.fetch_translations(countries_data)
        assert mock_extract.call_count == expected_calls
        assert len(result) == expected_calls


# Integration-style test that mocks external dependencies but tests the full flow
@patch("requests.Session.get")
@patch("boto3.client")
def test_integration(
    mock_boto_client, mock_session_get, sample_countries_data, sample_translation_data
):
    """Test the entire flow with mocked external dependencies."""

    # Setup mocks for API calls
    def mock_get_side_effect(url, **kwargs):
        mock_response = Mock()
        mock_response.raise_for_status.return_value = None

        if url == "https://restcountries.com/v3.1/all":
            mock_response.json.return_value = sample_countries_data
        else:
            mock_response.json.return_value = sample_translation_data

        return mock_response

    mock_session_get.side_effect = mock_get_side_effect

    # Setup mock for S3
    mock_s3 = Mock()
    mock_boto_client.return_value = mock_s3

    # Run the main function
    country_extraction.run()

    # Verify the entire flow
    today = date.today().strftime("%Y-%m-%d")

    # Verify S3 uploads
    assert mock_s3.put_object.call_count == 2
    mock_s3.put_object.assert_any_call(
        Body=json.dumps(sample_countries_data, indent=4),
        Bucket="countries_extraction",
        Key=f"countries/{today}/countries.json",
        ContentType="application/json",
    )
