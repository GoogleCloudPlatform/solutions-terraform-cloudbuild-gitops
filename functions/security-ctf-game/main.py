import os
import json
from google.cloud import firestore

def security_ctf_game(request):
    # declare environment variables
    PROJECT_NAME = os.environ.get('PROJECT_NAME')
    db = firestore.Client(project=PROJECT_NAME)

    event = json.loads(request.get_data().decode('UTF-8'))
    
    try:
        if event['action'] == 'Create':
            db.collection("security-ctf-games").document(event['game_name']).set({"state": "Created", "created": firestore.SERVER_TIMESTAMP})
        elif event['action'] == 'Start':
            db.collection("security-ctf-games").document(event['game_name']).update({"state": "Started", "started": firestore.SERVER_TIMESTAMP})
        elif event['action'] == 'End':
            db.collection("security-ctf-games").document(event['game_name']).update({"state": "Ended", "ended": firestore.SERVER_TIMESTAMP})  
        print(f"{event['action']} action succeeded for Game: {event['game_name']}!")
        info = f"{event['action']}: Successful"
    except Exception as error:
        print(f"{event['action']} action failed for Game: {event['game_name']}! - {error}")
        info = f"{event['action']} Error: {error}"
    
    data = {
        "info": info
    }
    return json.dumps(data), 200, {'Content-Type': 'application/json'}