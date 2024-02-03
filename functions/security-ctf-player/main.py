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
        info = ":wave:"
        
        ###################
        ## Enroll Action ##
        ###################
                
        if event['action'] == "Enroll":
            if game_doc.exists:
                if game_doc.get("state") == "Started":
                    player_doc = player_ref.get()
                    if player_doc.exists:
                        current_challenge = player_doc.get('current_challenge')
                        if current_challenge == "Completed!":
                            info = f"Game up! We'll see you in the next edition!:wave:"
                        elif current_challenge == "Accepted!":
                            info = "Serve Challenge 01"
                        elif current_challenge.startswith("Solving"):
                            info = "Serve Challenge " + current_challenge[-2:]
                        elif current_challenge.startswith("Solved"):
                            info = "Serve Challenge {:02d}".format(int(current_challenge[-2:]) + 1)
                        else:
                            info = f"You're already enrolled in the game. :face_with_rolling_eyes:\nPress the Play button to begin!"
                    else:
                        print(f"Enrolling Player: {event['player_name']}, {event['player_id']} to Game: {event['game_name']}")
                        player_ref.set({
                            "player_name": event['player_name'],
                            "started": firestore.SERVER_TIMESTAMP,
                            "total_score": 0,
                            "current_challenge": "Accepted!"
                        })
                        info = f"This ain't a game for the faint hearted! :ghost:\nPress the Play button when you're ready to take off. :airplane:"
                elif game_doc.get("state") == "Ended":
                    info = ":x: Sorry, this game has already ended! Keep an eye out for the next game. :eyes:"
                else:
                    info = ":warning: Sorry, this game is yet to begin! Keep an eye out for the announcement. :eyes:"
            else:
                info = f":exclamation: Invalid game code! Remember, game codes are case-sensitive. :capital_abcd:"
        elif event['action'] == "play":
            player_doc  = player_ref.get()
            if game_doc.get("state") == "Started":
                challenge_id = event['challenge_id']
                try:
                    challenge_score = player_doc.get(f"{challenge_id}.score")
                    print(f"Game: {event['game_name']}, Challenge: {challenge_id} for Player: {event['player_id']} - ignoring duplicate answer...")
                except:
                    challenge_doc = db.collection(challenges_collection).document(challenge_id).get()
                    challenge_score = 0
                    total_score     = player_doc.get('total_score')
                    result          = ":x: You've got it wrong baby! Better luck in the next one. :thumbsup:"
                    
                    ################### compute challenge score ###################
                    time_limit      = int(challenge_doc.get('time_limit'))
                    time_elapsed    = datetime.now().timestamp() - player_doc.get(f"{challenge_id}.start_time").timestamp_pb().seconds

                    if time_limit > 0 and time_elapsed > time_limit*60:
                        result = f":thumbsdown: Sorry, we didn't receive your response within {time_limit} mins. :cry:"
                    else:
                        eligible_score = int(challenge_doc.get('full_score')) - max(0, time_elapsed - 180)
                        if event['option_id'] == challenge_doc.get('answer') and player_doc.get(f"{challenge_id}.hint_taken"):
                            result = ":clap: Congratulations! You answered correctly but with a hint. :slightly_smiling_face:"
                            challenge_score = int(eligible_score/2)
                        elif event['option_id'] == challenge_doc.get('answer') and not player_doc.get(f"{challenge_id}.hint_taken"):
                            result = ":tada: Congratulations! Max marks for your right answer! :muscle:"
                            challenge_score = int(eligible_score)
                    
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
                                        "text": f"*Level:* {challenge_doc.get('category')}"
                                    },
                                    {
                                        "type": "mrkdwn",
                                        "text": f"*Score:* {challenge_score}"
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
                if event['action'] == "hint":
                    hint_taken = True
                    player_ref.update({
                            f"{event['challenge_id']}.hint_taken": hint_taken
                        })
                else:
                    try:
                        player_doc  = player_ref.get()
                        hint_taken  = player_doc.get(f"{event['challenge_id']}.hint_taken")
                    except:
                        hint_taken = False
                        player_ref.update({
                            event['challenge_id']: {
                                "start_time": firestore.SERVER_TIMESTAMP,
                                "hint_taken": False
                            },
                            "current_challenge": f"Solving {event['challenge_id'][-2:]}"
                        })
                info = f"Serving Game: {event['game_name']}, Challenge: {event['challenge_id']} for Player: {event['player_id']} Hint: {hint_taken}"
                send_slack_challenge(event['response_url'], event['game_name'], event['challenge_id'], hint_taken, player_ref)
            
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
            player_doc  = player_ref.get()
            reply_by    = (datetime.fromtimestamp(player_doc.get(f"{challenge_id}.start_time").timestamp_pb().seconds) + timedelta(minutes = time_limit)).astimezone(timezone('Asia/Kolkata')).strftime('%H:%M:%S')    
            if hint_taken:
                time_message    = f"Respond within {time_limit} mins by {reply_by} IST! {challenge_doc.get('hint_score')} points if you solve in 3 mins! :hourglass_flowing_sand:"
            else:
                time_message    = f"Respond within {time_limit} mins by {reply_by} IST! {challenge_doc.get('full_score')} points if you solve in 3 mins! :hourglass_flowing_sand:"
        else:
            if hint_taken:
                time_message    = f"There's no time limit for this question, so take your time and score {challenge_doc.get('hint_score')} points! :relaxed:"
            else:
                time_message    = f"There's no time limit for this question, so take your time and score {challenge_doc.get('full_score')} points! :relaxed:"

        message_blocks = [
                {
                    "type": "header",
                    "text": {
                        "type": "plain_text",
                        "text": f":mega: New Challenge: {challenge_doc.get('name')}!"
                    }
                },
                {
                    "type": "divider"
                },
                {
                    "type": "section",
                    "text": {
                        "type": "mrkdwn",
                        "text": f"*Scenario:* {challenge_doc.get('description')} :bomb:\n\n*Task:* {challenge_doc.get('task')} :male-detective:"
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
                        "text": "*Select your answer:* :mag:"
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
                    "text": f"*Hint:* {challenge_doc.get('hint')} :key:"
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
                    "text": f":pushpin: You can opt to take a hint. But a correct answer with a hint gets you half the points. :neutral_face:"
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
                "text": ":star2: Congratulations! You've reached the end of the CTF. :face_with_cowboy_hat:\n"
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
				"text": ":checkered_flag: Check out the *Leaderboard <https://secops-project-348011.web.app/|here>*"
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