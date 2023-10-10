import os
import json
import requests
from google.cloud import firestore

def security_ctf_player(request):
    # declare environment variables
    PROJECT_NAME = os.environ.get('PROJECT_NAME')
    db = firestore.Client(project=PROJECT_NAME)

    event = json.loads(request.get_data().decode('UTF-8'))
    
    try:
        info = "Do nothing!"
        if event['action'] == "Enroll":
            game_doc = db.collection("security-ctf-games").document(event['game_name']).get()
            if game_doc.exists:
                if game_doc.get("state") == "Started":
                    player_doc = db.collection("security-ctf-games").document(event['game_name']).collection('playerList').document(event['player_id']).get()
                    if player_doc.exists:
                        info = f"You're already enrolled in Game: {event['game_name']}. Press Play to begin!"
                    else:
                        print(f"Enrolling Player: {event['player_name']}, {event['player_id']} to Game: {event['game_name']}")
                        db.collection("security-ctf-games").document(event['game_name']).collection('playerList').document(event['player_id']).set({
                            "player_name": event['player_name'],
                            "started": firestore.SERVER_TIMESTAMP,
                            "total_score": 0,
                            "last_challenge": 0
                        })
                        info = f"Welcome to {event['game_name']}! When you're ready, press the Play button below."
                else:
                    info = f"Game: {event['game_name']} is yet to begin! Please contact the CTF admin."
            else:
                info = f"Game: {event['game_name']} is invalid! Please contact the CTF admin."
        elif event['action'] == "Play":
            info = f"Player: {event['player_id']}. Serving challenge: {event['next_challenge']}"
            if send_slack_challenge(db, event['game_name'], event['player_id'], event['next_challenge']):
                next_challenge = event['next_challenge']
                db.collection("security-ctf-games").document(event['game_name']).collection('playerList').document(event['player_id']).update({
                                [next_challenge]: {
                                    "start_time": firestore.SERVER_TIMESTAMP,
                                    "hint_taken": False
                                }
                            })
            return {
                'statusCode': 200,
                'body': json.dumps("Completed!")
            }
        print(info)
    except Exception as error:
        print(f"{event['action']} action failed for Game: {event['game_name']}! - {error}")
        info = f"{event['action']} Error: {error}"
    
    data = {
        "info": info
    }
    return json.dumps(data), 200, {'Content-Type': 'application/json'}

def send_slack_challenge(db, game_name, player_id, challenge_id):
    try:
        challenge_doc = db.collection("security-ctf-challenges").document(challenge_id).get()
        next_challenge = "ch{:02d}".format(int(challenge_id[-2:]) + 1)
        slack_message = [
                {
                    "type": "header",
                    "text": {
                        "type": "plain_text",
                        "text": f"New Challenge: {challenge_doc.get('Name')}!"
                    }
                },
                {
                    "type": "divider"
                },
                {
                    "type": "section",
                    "text": {
                        "type": "mrkdwn",
                        "text": f"*Description*\n{challenge_doc.get('Description')}"
                    },
                    "accessory": {
                        "type": "image",
                        "image_url": "https://api.slack.com/img/blocks/bkb_template_images/notifications.png",
                        "alt_text": "calendar thumbnail"
                    }
                },
                {
                    "type": "divider"
                },
                {
                    "type": "section",
                    "text": {
                        "type": "mrkdwn",
                        "text": "*Select your answer:*"
                    }
                }
            ]
        for option in range(1, 5):
            option_id = f"Option {option}"
            option_desc = challenge_doc.get('option_id')
            slack_message.append({
                "type": "section",
                "text": {
                    "type": "mrkdwn",
                    "text": f"*{option_id}*\n{option_desc}"
                },
                "accessory": {
                    "type": "button",
                    "text": {
                        "type": "plain_text",
                        "emoji": True,
                        "text": "Choose"
                    },
                    "value": f"type=player+game_name={game_name}+action=Play+option={option_id}+next_challenge={next_challenge}",
                }
		    })
        slack_token = os.environ.get('SLACK_ACCESS_TOKEN', 'Specified environment variable is not set.')
        response = requests.post("https://slack.com/api/chat.postMessage", data={
            "token": slack_token,
            "channel": player_id,
            "text": f"Challenge {challenge_doc.get('Name')}",
            "blocks": json.dumps(slack_message)
        })
        print(f"Slack responded with Status Code: {response.status_code}")
        return True
    except Exception as e:
        print(e)
        return False
