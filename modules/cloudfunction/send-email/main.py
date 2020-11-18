import base64
import json
from sendgrid import SendGridAPIClient
from sendgrid.helpers.mail import Mail


def send_email(event, context):
    """Triggered from a message on a Cloud Pub/Sub topic.
    Args:
         event (dict): Event payload.
         context (google.cloud.functions.Context): Metadata for the event.
    """
    pubsub_message = base64.b64decode(event['data']).decode('utf-8')
    json_obj = json.loads(pubsub_message)
    #print(json_obj)

    client_email = json_obj['data']['client']['email']
    if len(client_email) == 0:
        print("No email set")
        exit()

    result = json_obj['data']['output']
    print(result)
    from_email = 'cap.multicloud@gmail.com'
    
    subject = 'cenas'
    html_content = 'cenas'

    if result == True:
        subject = 'Sucesso'
        html_content = 'Sucesso'
    elif result == False:
        subject = 'Insucesso'
        html_content = 'Insucesso'
    

    message = Mail(
        from_email=from_email,
        to_emails=client_email,
        subject=subject,
        html_content=html_content)
    try:
        sg = SendGridAPIClient('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')  # noqa
        response = sg.send(message)
        print(response.status_code)
        print(response.body)
        print(response.headers)
    except Exception as e:
        print(str(e))
