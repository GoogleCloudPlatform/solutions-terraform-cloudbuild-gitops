import os
import csv
# import firebase_admin
# from firebase_admin import firestore
from google.cloud import storage

# declare environment variables
PROJECT_NAME = os.environ.get('PROJECT_NAME')
storage_client = storage.Client(project=PROJECT_NAME)

def security_ctf_challenges(event, context):
    """Triggered by a change to a Cloud Storage bucket.
    Args:
         event (dict): Event payload.
         context (google.cloud.functions.Context): Metadata for the event.
    """
    print(f"Processing file: {event['name']}.")

    try:
        mybucket = storage_client.get_bucket(event['bucket'])
        blob = mybucket.get_blob(event['name'])
        print(f"Input file fetch successful! Content Type: {event['contentType']}")

        csvfile = blob.download_as_bytes()
        csvcontent = csvfile.decode('utf-8').splitlines()
        lines = csv.reader(csvcontent)
        for line in lines:
            print(line)
        
    except Exception as e:
        print(e)
        print("Input file read unsuccessful!")
        