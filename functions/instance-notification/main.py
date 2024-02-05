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

    try:
        search_asset_client     = asset_v1.AssetServiceClient()
        search_asset_request    = asset_v1.SearchAllResourcesRequest(
            scope="projects/pensande",
            query="NOT tagKeys:network",
            asset_types="compute.googleapis.com/Instance",
            format="value(name)"
        )
        search_asset_result = search_asset_client.search_all_resources(request = search_asset_request)
        for search_asset in search_asset_result:
            print(search_asset)
    except Exception as error:
        print(f"Error in listing non-compliant instances: {error}")

    try:
        tag_bindings_client     = resourcemanager_v3.TagBindingsClient()
        tag_bindings_request    = resourcemanager_v3.ListTagBindingsRequest(
            parent = message_json["asset"]["name"]
        )
        tag_bindings_result     = tag_bindings_client.list_tag_bindings(request = tag_bindings_request)
        for tag_bindings in tag_bindings_result:
            print(tag_bindings)
    except Exception as error:
        print(f"Error in listing tag bindings: {error}")
    