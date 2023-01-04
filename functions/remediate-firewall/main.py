import time
import json
import requests
import googleapiclient.discovery
from pytz import timezone 
from datetime import datetime

def remediate_firewall(request):
    # processing the remediate_firewall request
    event = json.loads(request.get_data().decode('UTF-8'))
    response_timestamp = datetime.now(timezone("Asia/Kolkata")).strftime('%Y-%m-%d %H:%M:%S')
    project_name = event['value'].split("project_name=")[1].split("+")[0]
    resource_name = event['value'].split("resource_name=")[1].split("+")[0]

    result = delete_firewall(project_name,resource_name)
    if result:
        response_subject = "Misconfigured firewall rule deleted successfully!"
    else:
        response_subject = "Misconfigured firewall rule deletion failed!"

    slack_message = {
        "text": f"{response_subject}\n",
        "blocks": [ 
            {
                "type": "header",
                "text": {
                    "type": "plain_text",
                    "text": "Remediate Action Taken"
                }
            },
            {
                "type": "divider"
            },
            {
                "type": "section",
                "text": {
                    "type": "mrkdwn",
                    "text": f"{response_subject}\n"
                }
            },
            {
                "type": "section",
                "fields": [
                    {
                        "type": "mrkdwn",
                        "text": f"*Requestor:*\n{event['caller_name']}"
                    },
                    {
                        "type": "mrkdwn",
                        "text": f"*When:*\n{response_timestamp} IST"
                    },
                    {
                        "type": "mrkdwn",
                        "text": f"*Project:*\n{project_name}"
                    },
                    {
                        "type": "mrkdwn",
                        "text": f"*Resource:*\n{resource_name}"
                    }
                ]
            }
        ]
    }
    post_slack_response(event['response_url'],slack_message)
    return {
        'statusCode': 200,
        'body': json.dumps("Completed!")
    }

def delete_firewall(project_name,resource_name):
    try:
        print(f"Deleting firewall {resource_name} from {project_name}...")
        compute = googleapiclient.discovery.build('compute', 'v1')
        request = compute.firewalls().delete(project=project_name,firewall=resource_name)
        response = request.execute()
        wait_for_operation(compute, project_name, response['name'])
        return True
    except Exception as e:
        print(e)
        return False

def wait_for_operation(compute, project_name, operation):
    print('Waiting for operation to finish...')
    while True:
        result = compute.globalOperations().get(
            project=project_name,
            operation=operation).execute()

        if result['status'] == 'DONE':
            if 'error' in result:
                raise Exception(result['error'])
            else:
                resource_name = result['targetLink'].split("/")[-2] + "/" + result['targetLink'].split("/")[-1] 
                print(f"Operation: {result['operationType']} on Resource: {resource_name} in Project: {project_name} successful!")

            return result

        time.sleep(1)

def post_slack_response(response_url,slack_message):
    response = requests.post(response_url, data=json.dumps(slack_message), headers={'Content-Type': 'application/json'})
    if response.status_code == 200:
        print("Slack response sent successfully.")
        return True
    else:
        print("Slack response failed.")
        return False