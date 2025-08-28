import os
import csv
import json
from google.cloud import storage
from google.api_core.client_options import ClientOptions
from google.cloud import modelarmor_v1

# declare environment variables
PROJECT_ID  = os.environ.get('PROJECT_ID')
LOCATION_ID = os.environ.get('LOCATION_ID')
TEMPLATE_ID = os.environ.get('TEMPLATE_ID')
RESULT_B    = os.environ.get('RESULT_B')

# create clients
storage_client = storage.Client(project=PROJECT_ID)

print("Creating Model Armor client...")
client = modelarmor_v1.ModelArmorClient(
    transport="rest",
    client_options=ClientOptions(
        api_endpoint=f"modelarmor.{LOCATION_ID}.rep.googleapis.com"
    ),
)
print("Model Armor client created!")

def model_armor(event, context):
    """Triggered by a change to a Cloud Storage bucket.
    Args:
         event (dict): Event payload.
         context (google.cloud.functions.Context): Metadata for the event.
    """
    print(f"Processing file: {event['name']}.")

    try:
        prompt_bucket = storage_client.get_bucket(event['bucket'])
        blob = prompt_bucket.get_blob(event['name'])
        
        if event['contentType']=='text/csv':
            csvfile = blob.download_as_bytes()
            csvcontent = csvfile.decode('utf-8').splitlines()
            lines = csv.reader(csvcontent)
            
            header = 0
            
            with open('/tmp/prompt-scanning-results.csv', 'w', newline='') as f:
                w = csv.writer(f)
                w.writerow(['id','prompt','response','verdict'])
            
                for line in lines:
                    if header == 0:
                        header_row = line
                        header += 1
                    else:
                        index = 0
                        for column in line:
                            if index == 0:
                                prompt_id = column 
                            elif index == 1:
                                response, verdict = sanitize_prompt(column)
                                w.writerow([prompt_id, column, response, verdict])    
                            index += 1
            
            # writing results to the result bucket
            result_bucket = storage_client.get_bucket(RESULT_B)
            print("Writing results to the results bucket...")
            blob = result_bucket.blob(f"ma_scanned_{event['name']}")
            blob.upload_from_filename("/tmp/prompt-scanning-results.csv")
            print("Results written to the results bucket!")
        else:
            print(f"Sorry, I cannot process the file format: {event['contentType']}!")
    
    except Exception as e:
        print(e)
        print("Input file read unsuccessful!")

def sanitize_prompt(user_prompt):
    # Initialize request argument(s).
    user_prompt_data = modelarmor_v1.DataItem(text=user_prompt)

    # Prepare request for sanitizing the defined prompt.
    request = modelarmor_v1.SanitizeUserPromptRequest(
        name                =   TEMPLATE_ID,
        user_prompt_data    =   user_prompt_data,
    )

    # Sanitize the user prompt.
    response = client.sanitize_user_prompt(request=request)

    matched_filters = []

    for filter_name, filter_result in response.sanitization_result.filter_results.items():
        if filter_result.sdp_filter_result.inspect_result.match_state.name == "MATCH_FOUND":
            matched_filters.append(filter_name)
        elif filter_result.rai_filter_result.match_state.name == "MATCH_FOUND":
            matched_filters.append(filter_name)
        elif filter_result.pi_and_jailbreak_filter_result.match_state.name == "MATCH_FOUND":
            matched_filters.append(filter_name)
        elif filter_result.malicious_uri_filter_result.match_state.name == "MATCH_FOUND":
            matched_filters.append(filter_name)
        elif filter_result.csam_filter_filter_result.match_state.name == "MATCH_FOUND":
            matched_filters.append(filter_name)
    
    matched_filters_string = ", ".join(matched_filters) if matched_filters else "None"

    # Return the sanitization result.
    return matched_filters_string, response.sanitization_result.filter_match_state.name