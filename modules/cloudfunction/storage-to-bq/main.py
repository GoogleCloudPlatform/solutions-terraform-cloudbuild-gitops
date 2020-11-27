from google.cloud import storage, bigquery
import json 
import uuid
from datetime import datetime

def storageToBq(event, context):
    """Triggered by a change to a Cloud Storage bucket.
    Args:
         event (dict): Event payload.
         context (google.cloud.functions.Context): Metadata for the event.
    """

    # create storage client
    # storage_client = storage.Client.from_service_account_json('/Users/ey/testpk.json')
    storage_client = storage.Client()
    # get bucket with name
    bucket = storage_client.get_bucket(event['bucket'])
    # get bucket data as blob
    blob = bucket.get_blob(event['name'])
    # convert to string
    json_data = blob.download_as_string()
    print(json_data)
    json_data_dict = json.loads(json_data.decode('utf8'))
    
    bigquery_client = bigquery.Client()

    # Prepares a reference to the dataset
    dataset_ref = bigquery_client.dataset('bank')

    table_ref = dataset_ref.table('transactions')
    table = bigquery_client.get_table(table_ref)  # API call

    n_transactions = len(json_data_dict['transactions'])
    rows_to_insert = []

    for x in range(n_transactions):
        id = str(uuid.uuid4())[-12:]
        #source_account_id = int(json_data_dict['transactions'][x]['sourceAccountId'])
        #target_account_id = int(json_data_dict['transactions'][x]['targetAccountId'])
        amount = json_data_dict['transactions'][x]['amount']
        description = json_data_dict['transactions'][x]['description']
        #date_time = d['transactions'][x]['dateTime']
        date_time = str(datetime.now().strftime("%Y-%m-%dT%H:%M:%S"))

        rows_to_insert.append((id, source_account_id, target_account_id, date_time, amount, description))    

    print(rows_to_insert)

    errors = bigquery_client.insert_rows(table, rows_to_insert)  # API request

    for x in errors:
        print(x)