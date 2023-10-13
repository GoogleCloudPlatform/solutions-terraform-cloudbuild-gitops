import os
import json
import requests
from pytz import timezone 
from datetime import datetime, timedelta
from google.cloud import firestore

# declare environment variables
PROJECT_NAME = os.environ.get('PROJECT_NAME')
games_collection = os.environ.get('GAMES_COLLECTION')
challenges_collection = os.environ.get('CHALLENGES_COLLECTION')
time_limit = int(os.environ.get('TIME_LIMIT', '600'))
last_challenge = os.environ.get('LAST_CHALLENGE')
db = firestore.Client(project=PROJECT_NAME)

def security_ctf_player(request):
    
    event       = json.loads(request.get_data().decode('UTF-8'))
    game_ref    = db.collection(games_collection).document(event['game_name'])
    player_ref  = db.collection(games_collection).document(event['game_name']).collection('playerList').document(event['player_id'])
    game_doc    = game_ref.get()
            
    try:
        info = "Do nothing!"
        
        ###################
        ## Enroll Action ##
        ###################
                
        if event['action'] == "Enroll":
            if game_doc.exists:
                if game_doc.get("state") == "Started":
                    player_doc = player_ref.get()
                    if player_doc.exists:
                        info = f"You're already enrolled in the game.\nPress the Play button to begin!"
                    else:
                        print(f"Enrolling Player: {event['player_name']}, {event['player_id']} to Game: {event['game_name']}")
                        player_ref.set({
                            "player_name": event['player_name'],
                            "started": firestore.SERVER_TIMESTAMP,
                            "total_score": 0,
                            "current_challenge": 0
                        })
                        info = f"This ain't a game for the faint hearted!\nPress the Play button when you're ready."
                else:
                    info = f"Game is yet to begin!"
            else:
                info = f"Invalid game code!\nCodes are case-sensitive."
        elif event['action'] == "play":
            player_doc  = player_ref.get()
            if game_doc.get("state") == "Started":
                challenge_id = event['challenge_id']
                challenge_doc = db.collection(challenges_collection).document(challenge_id).get()

                if challenge_id > "ch00":
                    challenge_score = 0
                    total_score     = player_doc.get('total_score')
                    result          = "You've got it wrong baby! Better luck in the next one."
                    
                    ################### compute challenge score ###################
                    if datetime.now().timestamp() - player_doc.get(f"{challenge_id}.start_time").timestamp_pb().seconds > time_limit:
                        result = "Sorry, we didn't receive your response within 10 mins."
                    else:
                        if event['option_id'] == challenge_doc.get('answer') and player_doc.get(f"{challenge_id}.hint_taken"):
                            result = "Congratulations! You answered correctly but with a hint!"
                            challenge_score = 5
                        elif event['option_id'] == challenge_doc.get('answer') and not player_doc.get(f"{challenge_id}.hint_taken"):
                            result = "Congratulations! You got the right answer!"
                            challenge_score = 10
                    
                    ################### update challenge score ##########
                    player_ref.update({
                        f"{challenge_id}.resp_time": firestore.SERVER_TIMESTAMP,
                        f"{challenge_id}.answer": event['option_id'],
                        f"{challenge_id}.score": challenge_score
                    })
                    
                    ################### update total score ##############
                    total_score += challenge_score
                    player_ref.update({"total_score": total_score})

                    ################### announce challenge result ##############
                    slack_message = {
                        "text": f"{result}\n",
                        "blocks": [ 
                            {
                                "type": "header",
                                "text": {
                                    "type": "plain_text",
                                    "text": f"Challenge: {challenge_doc.get('name')}"
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
                                        "text": f"*Level:*\n{challenge_doc.get('category')}"
                                    },
                                    {
                                        "type": "mrkdwn",
                                        "text": f"*Score:*\n{challenge_score}"
                                    }
                                ]
                            }
                        ]
                    }
                    response = requests.post(event['response_url'], data=json.dumps(slack_message), headers={'Content-Type': 'application/json'})
                    print(f"Game: {event['game_name']}, Challenge: {event['challenge_id']} for Player: {event['player_id']} announced with Status Code: {response.status_code}")

                    ################### end game and announce game score ##############
                    if challenge_id == last_challenge:
                        response_code = announce_game_end(event['game_name'], event['player_id'], total_score)
                        info = f"Game: {event['game_name']} End for Player: {event['player_id']} responded with Status Code: {response_code}"
                
                ################### send next challenge and update database ##############
                if challenge_id < last_challenge:
                    next_challenge = "ch{:02d}".format(int(challenge_id[-2:]) + 1)
                    info = f"Serving Game: {event['game_name']}, Challenge: {next_challenge} for Player: {event['player_id']} "
                    if send_slack_challenge(event['game_name'], event['player_id'], next_challenge, False):
                        player_ref.update({
                            next_challenge: {
                                "start_time": firestore.SERVER_TIMESTAMP,
                                "hint_taken": False
                            },
                            "current_challenge": int(next_challenge[-2:])
                        })
            
            ################### end game and announce game score ##############
            else:
                total_score     = player_doc.get('total_score')
                response_code   = announce_game_end(event['game_name'], event['player_id'], total_score)
                info            = f"Game: {event['game_name']} End for Player: {event['player_id']} responded with Status Code: {response_code}"

        ################### serve hint and update database ##############
        elif event['action'] == "hint":
            if game_doc.get("state") == "Started":    
                info = f"Serving Game: {event['game_name']}, Challenge: {event['challenge_id']} for Player: {event['player_id']} Hint: {event['challenge_id']}"
                if send_slack_challenge(event['game_name'], event['player_id'], event['challenge_id'], True):
                    player_ref.update({
                        f"{event['challenge_id']}.hint_taken": True
                    })
            
            ################### end game and announce game score ##############
            else:
                player_doc      = player_ref.get()
                total_score     = player_doc.get('total_score')
                response_code   = announce_game_end(event['game_name'], event['player_id'], total_score)
                info            = f"Game: {event['game_name']} End for Player: {event['player_id']} responded with Status Code: {response_code}"
    except Exception as error:
        info = f"{event['action']} for Game: {event['game_name']} failed! Error: {error}"
    
    print(info)
    data = {
        "info": info
    }
    return json.dumps(data), 200, {'Content-Type': 'application/json'}

def send_slack_challenge(game_name, player_id, challenge_id, hint_taken):
    try:
        reply_by = (datetime.now(timezone("Asia/Kolkata"))+ timedelta(minutes = 10)).strftime('%H:%M:%S')
        challenge_doc = db.collection(challenges_collection).document(challenge_id).get()

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
        if hint_taken:
            slack_message.extend([{
                "type": "divider"
            },
            {
                "type": "section",
                "text": {
                    "type": "mrkdwn",
                    "text": f"*Hint:*\n{challenge_doc.get('hint')}"
                }
            }])
        else:
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

def announce_game_end(game_name, player_id, total_score):
    slack_message = [ 
        {
            "type": "header",
            "text": {
                "type": "plain_text",
                "text": f"End of CTF: {game_name}"
            }
        },
        {
            "type": "divider"
        },
        {
            "type": "section",
            "text": {
                "type": "mrkdwn",
                "text": "Congratulations! You've reached the end of the CTF.\n"
            }
        },
        {
            "type": "section",
            "fields": [
                {
                    "type": "mrkdwn",
                    "text": f"*Total Score:*\n{total_score}"
                }
            ]
        }
    ]
    slack_token = os.environ.get('SLACK_ACCESS_TOKEN', 'Specified environment variable is not set.')
    response = requests.post("https://slack.com/api/chat.postMessage", data={
        "token": slack_token,
        "channel": player_id,
        "text": f"End of CTF: {game_name}",
        "blocks": json.dumps(slack_message)
    })
    return response.status_code