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
                        info = f"You're already enrolled in the game. Press the Play button to begin!"
                    else:
                        print(f"Enrolling Player: {event['player_name']}, {event['player_id']} to Game: {event['game_name']}")
                        player_ref.set({
                            "player_name": event['player_name'],
                            "started": firestore.SERVER_TIMESTAMP,
                            "total_score": 0,
                            "current_challenge": "Accepted!"
                        })
                        info = f"This ain't a game for the faint hearted!\nPress the Play button when you're ready."
                elif game_doc.get("state") == "Ended":
                    info = "Sorry, this game has already ended!\n"
                else:
                    info = "Sorry, this game is yet to begin!\n"
            else:
                info = f"Invalid game code! Remember, game codes are case-sensitive."
        elif event['action'] == "play":
            player_doc  = player_ref.get()
            if game_doc.get("state") == "Started":
                challenge_id = event['challenge_id']
                challenge_doc = db.collection(challenges_collection).document(challenge_id).get()

                challenge_score = 0
                total_score     = player_doc.get('total_score')
                result          = "You've got it wrong baby! Better luck in the next one."
                
                ################### compute challenge score ###################
                time_limit = int(challenge_doc.get('time_limit'))
                if time_limit > 0 and datetime.now().timestamp() - player_doc.get(f"{challenge_id}.start_time").timestamp_pb().seconds > time_limit*60:
                    result = f"Sorry, we didn't receive your response within {time_limit} mins."
                else:
                    if event['option_id'] == challenge_doc.get('answer') and player_doc.get(f"{challenge_id}.hint_taken"):
                        result = "Congratulations! You answered correctly but with a hint!"
                        challenge_score = int(challenge_doc.get('hint_score'))
                    elif event['option_id'] == challenge_doc.get('answer') and not player_doc.get(f"{challenge_id}.hint_taken"):
                        result = "Congratulations! You got the right answer!"
                        challenge_score = int(challenge_doc.get('full_score'))
                
                ################### update challenge score ####################
                player_ref.update({
                    "current_challenge": f"Solved {challenge_id[-2:]}",                    
                    f"{challenge_id}.resp_time": firestore.SERVER_TIMESTAMP,
                    f"{challenge_id}.answer": event['option_id'],
                    f"{challenge_id}.score": challenge_score
                })
                
                ################### update total score ########################
                total_score += challenge_score
                player_ref.update({"total_score": total_score})

                ################### announce challenge result #################
                slack_message = {
                    "text": f"{result}",
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

                ################### send next challenge interstitial ##############
                if challenge_id < last_challenge:
                    next_challenge = "ch{:02d}".format(int(challenge_id[-2:]) + 1)
                    slack_message = [
                        {
                            "type": "header",
                            "text": {
                                "type": "plain_text",
                                "text": f"Security CTF: {event['game_name']}"
                            }
                        },
                        {
                            "type": "divider"
                        },
                        {
                            "type": "actions",
                            "elements": [
                                {
                                    "type": "button",
                                    "text": {
                                        "type": "plain_text",
                                        "emoji": True,
                                        "text": f"Serve Challenge {next_challenge[-2:]}"
                                    },
                                    "style": "primary",
                                    "value": f"type=player+game_name={event['game_name']}+action=serve+challenge_id={next_challenge}",
                                }
                            ]
                        }
                    ]
                    response_code = post_slack_message(event['player_id'], info, slack_message)
                    info = f"Game: {event['game_name']}, Interstitial: {next_challenge} for Player: {event['player_id']} served with Status Code: {response_code}"
                ################### end game and announce game score ##############
                else:
                    response_code = announce_game_end(event['game_name'], event['player_id'], total_score)
                    info = f"Game: {event['game_name']} End for Player: {event['player_id']} responded with Status Code: {response_code}"
                    player_ref.update({
                        "current_challenge": "Completed!"
                    })   
            
            ################### end game and announce game score ##############
            else:
                total_score     = player_doc.get('total_score')
                response_code   = announce_game_end(event['game_name'], event['player_id'], total_score)
                info            = f"Game: {event['game_name']} End for Player: {event['player_id']} responded with Status Code: {response_code}"

        ################### serve challenge and update database ###############
        elif event['action'] == "hint" or event['action'] == "serve":
            if game_doc.get("state") == "Started":
                hint_taken = True if event['action'] == "hint" else False   
                info = f"Serving Game: {event['game_name']}, Challenge: {event['challenge_id']} for Player: {event['player_id']} Hint: {hint_taken}"
                if send_slack_challenge(event['response_url'], event['game_name'], event['challenge_id'], hint_taken, player_ref):
                    if hint_taken:
                        player_ref.update({
                            f"{event['challenge_id']}.hint_taken": hint_taken
                        })
                    else:
                        player_ref.update({
                            event['challenge_id']: {
                                "start_time": firestore.SERVER_TIMESTAMP,
                                "hint_taken": False
                            },
                            "current_challenge": f"Solving {event['challenge_id'][-2:]}"
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

def send_slack_challenge(response_url, game_name, challenge_id, hint_taken, player_ref):
    try:
        challenge_doc   = db.collection(challenges_collection).document(challenge_id).get()
        time_limit      = int(challenge_doc.get('time_limit'))
        
        if time_limit > 0:
            if hint_taken:
                player_doc  = player_ref.get()
                reply_by    = (datetime.fromtimestamp(player_doc.get(f"{challenge_id}.start_time").timestamp_pb().seconds) + timedelta(minutes = time_limit)).astimezone(timezone('Asia/Kolkata')).strftime('%H:%M:%S')
                time_message    = f"To score {challenge_doc.get('hint_score')} points, answer this question within {time_limit} mins by {reply_by} IST!"
            else:
                reply_by    = (datetime.now(timezone("Asia/Kolkata"))+ timedelta(minutes = time_limit)).strftime('%H:%M:%S')
                time_message    = f"To score {challenge_doc.get('full_score')} points, answer this question within {time_limit} mins by {reply_by} IST!"
        else:
            if hint_taken:
                time_message    = f"There's no time limit for this question, so take your time and score {challenge_doc.get('hint_score')} points!"
            else:
                time_message    = f"There's no time limit for this question, so take your time and score {challenge_doc.get('full_score')} points!"

        message_blocks = [
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
                        "text": f"*Scenario:* {challenge_doc.get('description')}\n\n*Task:* {challenge_doc.get('task')}"
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
                            "text": time_message
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
            message_blocks.append({
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
            message_blocks.extend([{
                "type": "divider"
            },
            {
                "type": "section",
                "text": {
                    "type": "mrkdwn",
                    "text": f"*Hint:* {challenge_doc.get('hint')}"
                }
            }])
        else:
            message_blocks.extend([{
                "type": "divider"
            },
            {
                "type": "section",
                "text": {
                    "type": "mrkdwn",
                    "text": f"You can opt to take a hint. A correct answer with a hint gets you only {challenge_doc.get('hint_score')} points."
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

        slack_message = {
            "text": f"Serving Game: {game_name}, Challenge: {challenge_id} Hint: {hint_taken}",
            "blocks": message_blocks
        }

        response = requests.post(response_url, data=json.dumps(slack_message), headers={'Content-Type': 'application/json'})
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
                    "text": f"*Total Score:* {total_score}"
                }
            ]
        },
        {
			"type": "section",
			"text": {
				"type": "mrkdwn",
				"text": "Check out the *Leaderboard <https://secops-project-348011.web.app/|here>*"
			}
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

def post_slack_message(slack_channel, slack_text, slack_message):
    slack_token = os.environ.get('SLACK_ACCESS_TOKEN', 'Specified environment variable is not set.')
    response = requests.post("https://slack.com/api/chat.postMessage", data={
        "token": slack_token,
        "channel": slack_channel,
        "text": slack_text,
        "blocks": json.dumps(slack_message)
    })
    return response.status_code