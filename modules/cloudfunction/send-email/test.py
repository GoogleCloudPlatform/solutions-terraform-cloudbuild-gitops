import base64
import json
from sendgrid import SendGridAPIClient
from sendgrid.helpers.mail import Mail

#json_obj = json.loads(pubsub_message)
#print(json_obj)

#client_email = json_obj['client_email']
client_email = 'cap.multicloud@gmail.com'
if len(client_email) == 0:
    print("No email set")
    exit()

from_email = 'cap.multicloud@gmail.com'
subject = 'cenas'
html_content = 'cenas'

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
