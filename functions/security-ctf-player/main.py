import os
import json
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
            db.collection("security-ctf-games").document(event['game_name']).collection('playerList').document(event['player_id']).set({
                            [event['next_challenge']]: {
                                "start_time": firestore.SERVER_TIMESTAMP,
                                "hint_taken": False
                            }
                        })
        print(info)
    except Exception as error:
        print(f"{event['action']} action failed for Game: {event['game_name']}! - {error}")
        info = f"{event['action']} Error: {error}"
    
    data = {
        "info": info
    }
    return json.dumps(data), 200, {'Content-Type': 'application/json'}