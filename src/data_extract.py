import requests
import json
import boto3

def extract_countries ():
    url = "https://restcountries.com/v3.1/all"
    response = requests.get(url)
    if response:
        return response.json()
    
    
def extract_translation(translation):
    url = f"https://restcountries.com/v3.1/translation/{translation}"
    response = requests.get(url)
    if response:
        return response.json()
    

def save_to_s3(bucket, file_path, dataset):
    s3_client = boto3.client('s3')
    s3_client.put_object(
        Body=json.dumps(dataset),
        Bucket=bucket,
        Key=file_path
    )
    

def run():
    countries_dataset = extract_countries()
    translations_dataset = []
    for country in countries_dataset:
        first_known_translation = next(iter(country['translations'].values()))['official']
        translation = extract_translation(first_known_translation)
        translations_dataset.append(translation)
    print(countries_dataset)
    print(translations_dataset)
        
        
run()