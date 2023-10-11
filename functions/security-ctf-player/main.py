import os
import json
import requests
from pytz import timezone 
from datetime import datetime, timedelta
from google.cloud import firestore

def security_ctf_player(request):
    # declare environment variables
    PROJECT_NAME = os.environ.get('PROJECT_NAME')
    db = firestore.Client(project=PROJECT_NAME)

    event       = json.loads(request.get_data().decode('UTF-8'))
    game_ref    = db.collection("security-ctf-games").document(event['game_name'])
    player_ref  = db.collection("security-ctf-games").document(event['game_name']).collection('playerList').document(event['player_id'])
    
    try:
        info = "Do nothing!"
        
        ###################
        ## Enroll Action ##
        ###################
                
        if event['action'] == "Enroll":
            game_doc = game_ref.get()
            if game_doc.exists:
                if game_doc.get("state") == "Started":
                    player_doc = player_ref.get()
                    if player_doc.exists:
                        info = f"You're already enrolled. Press Play to begin!"
                    else:
                        print(f"Enrolling Player: {event['player_name']}, {event['player_id']} to Game: {event['game_name']}")
                        player_ref.set({
                            "player_name": event['player_name'],
                            "started": firestore.SERVER_TIMESTAMP,
                            "total_score": 0,
                            "last_challenge": 0
                        })
                        info = f"Welcome to {event['game_name']}! When you're ready, press the Play button below."
                else:
                    info = f"Game is yet to begin! Please contact the CTF admin."
            else:
                info = f"Invalid game code! Please contact the CTF admin."
        elif event['action'] == "play":
            challenge_id = event['challenge_id']
            challenge_doc = db.collection("security-ctf-challenges").document(challenge_id).get()

            if challenge_id > "ch00":
                
                ################### compute score ###################
                challenge_score = 0
                player_doc = player_ref.get()
                if firestore.SERVER_TIMESTAMP.seconds - player_doc.get(f"{challenge_id}.start_time").seconds > 600:
                    result = "Sorry, we didn't receive your response within 10 mins."
                else:
                    if event['option'] == challenge_doc.get('answer') and player_doc.get(f"{challenge_id}.hint_taken"):
                        result = "Congratulations! You answered correctly but with a hint!"
                        challenge_score = 5
                    elif event['option'] == challenge_doc.get('answer') and not player_doc.get(f"{challenge_id}.hint_taken"):
                        result = "Congratulations! You got the right answer!"
                        challenge_score = 10
                print(result)
                ################### update challenge score ##########
                player_ref.update({
                    f"{challenge_id}.resp_time": firestore.SERVER_TIMESTAMP,
                    f"{challenge_id}.answer": event['option_id'],
                    f"{challenge_id}.score": challenge_score
                })
                
                ################### update total score ##############
                player_ref.update({"total_score": firestore.Increment(challenge_score)})

                slack_message = {
                    "text": f"{result}\n",
                    "blocks": [ 
                        {
                            "type": "header",
                            "text": {
                                "type": "plain_text",
                                "text": f"{event['game_name']}: {challenge_doc.get('name')}"
                            }
                        },
                        {
                            "type": "divider"
                        },
                        {
                            "type": "section",
                            "text": {
                                "type": "mrkdwn",
                                "text": f"{result}\n"
                            }
                        },
                        {
                            "type": "section",
                            "fields": [
                                {
                                    "type": "mrkdwn",
                                    "text": f"*Score:*\n{challenge_score}"
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
            if challenge_id < "ch10":
                next_challenge = "ch{:02d}".format(int(challenge_id[-2:]) + 1)
                info = f"Serving Game: {event['game_name']} Player: {event['player_id']} Challenge: {next_challenge}"
                if send_slack_challenge(db, event['game_name'], event['player_id'], next_challenge):
                    player_ref.update({
                        next_challenge: {
                            "start_time": firestore.SERVER_TIMESTAMP,
                            "hint_taken": False
                        }
                    })
                return {
                    'statusCode': 200,
                    'body': json.dumps("Completed!")
                }
        elif event['action'] == "hint":
            info = f"Serving Game: {event['game_name']} Player: {event['player_id']}. Hint: {event['challenge_id']}"
            challenge_doc = db.collection("security-ctf-challenges").document(event['challenge_id']).get()
            slack_message = {
                "thread_ts": event['thread_ts'],
                "text": challenge_doc.get('hint'),
                "response_type": "in_channel",
                "replace_original": False
            }
            if post_slack_response(event['response_url'], slack_message):
                player_ref.update({
                    f"{challenge_id}.hint_taken": True
                })
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
        reply_by = (datetime.now(timezone("Asia/Kolkata"))+ timedelta(minutes = 10)).strftime('%H:%M:%S')
        challenge_doc = db.collection("security-ctf-challenges").document(challenge_id).get()

        slack_message = [
                {
                    "type": "header",
                    "text": {
                        "type": "plain_text",
                        "text": f"New Challenge: {challenge_doc.get('name')}!"
                    }
                },
                {
                    "type": "divider"
                },
                {
                    "type": "section",
                    "text": {
                        "type": "mrkdwn",
                        "text": f"{challenge_doc.get('description')}\n{challenge_doc.get('task')}"
                    },
                    "accessory": {
                        "type": "image",
                        "image_url": "https://api.slack.com/img/blocks/bkb_template_images/notifications.png",
                        "alt_text": "calendar thumbnail"
                    }
                },
                {
                    "type": "context",
                    "elements": [
                        {
                            "type": "image",
                            "image_url": "https://api.slack.com/img/blocks/bkb_template_images/notificationsWarningIcon.png",
                            "alt_text": "notifications warning icon"
                        },
                        {
                            "type": "mrkdwn",
                            "text": f"To score points, answer this question within 10 mins by {reply_by} IST"
                        }
                    ]
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
            option_id = f"option_{option}"
            option_desc = challenge_doc.get(f"{option_id}")
            slack_message.append({
                "type": "section",
                "text": {
                    "type": "mrkdwn",
                    "text": f"{option_desc}"
                },
                "accessory": {
                    "type": "button",
                    "text": {
                        "type": "plain_text",
                        "emoji": True,
                        "text": "Choose"
                    },
                    "value": f"type=player+game_name={game_name}+action=play+option_id={option_id}+challenge_id={challenge_id}",
                }
		    })
        
        slack_message.extend([{
            "type": "divider"
        },
        {
            "type": "section",
            "text": {
                "type": "mrkdwn",
                "text": "You can opt to take a hint. A correct answer with a hint gets you only 5 points."
            }
        },
        {
            "type": "actions",
            "elements": [
                {
                    "type": "button",
                    "text": {
                        "type": "plain_text",
                        "text": "Take Hint",
                        "emoji": True
                    },
                    "value": f"type=player+game_name={game_name}+action=hint+challenge_id={challenge_id}"
                }
            ]
        }])

        slack_token = os.environ.get('SLACK_ACCESS_TOKEN', 'Specified environment variable is not set.')
        response = requests.post("https://slack.com/api/chat.postMessage", data={
            "token": slack_token,
            "channel": player_id,
            "text": f"Challenge {challenge_doc.get('name')}",
            "blocks": json.dumps(slack_message)
        })
        print(f"Slack responded with Status Code: {response.status_code}")
        return True
    except Exception as e:
        print(e)
        return False

def post_slack_response(url, slack_message):
    response = requests.post(url, data=json.dumps(slack_message), headers={'Content-Type': 'application/json'})
    print(f"Message posted - Slack responded with Status Code: {response.status_code}")
    if response.status_code == 200:
        return True
    else:
        return False