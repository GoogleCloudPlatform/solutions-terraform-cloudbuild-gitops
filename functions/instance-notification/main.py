import os
import json
import base64
import requests
from google.cloud import asset_v1
from google.cloud import resourcemanager_v3

def instance_notification(event, context):
    """Triggered from a message on a Cloud Pub/Sub topic.
    Args:
         event (dict): Event payload.
         context (google.cloud.functions.Context): Metadata for the event.
    """
    pubsub_message = base64.b64decode(event['data']).decode('utf-8')
    message_json = json.loads(pubsub_message)
    print(message_json)

    if message_json["asset"]["resource"]["data"]["status"] == 'RUNNING':
        try:
            search_asset_client     = asset_v1.AssetServiceClient()
            search_asset_request    = asset_v1.SearchAllResourcesRequest(
                scope       ="projects/pensande",
                query       ="NOT tagKeys:network",
                asset_types =["compute.googleapis.com/Instance"],
                read_mask   ="name"
            )
            search_asset_result = search_asset_client.search_all_resources(request = search_asset_request)
            for search_asset in search_asset_result:
                print(search_asset)
        except Exception as error:
            print(f"Error in listing non-compliant instances: {error}")
