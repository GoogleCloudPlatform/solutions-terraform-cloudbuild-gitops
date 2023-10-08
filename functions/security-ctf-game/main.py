import os
import json
from google.cloud import firestore
from google.cloud.firestore_v1.base_query import FieldFilter

def security_ctf_game(request):
    # declare environment variables
    PROJECT_NAME = os.environ.get('PROJECT_NAME')
    db = firestore.Client(project=PROJECT_NAME)

    event = json.loads(request.get_data().decode('UTF-8'))
    
    try:
        if event['action'] == 'Create':
            game = {"name": event['game_name'], "created": firestore.SERVER_TIMESTAMP, "state": "Active"}
            game_ref = db.collection("security-ctf-games").add(game)
            print(f"Created game with name: {event['game_name']}, id: {game_ref.id}")
        elif event['action'] == 'End':
            game_ref = db.collection("security-ctf-games").where(filter=FieldFilter("name", "==", event['game_name'])).stream()
            game_ref.update({"state": "Ended"})
            print(f"Ended game with name: {event['game_name']}, id: {game_ref.id}")
        info = f"{event['action']}: Successful"
    except Exception as error:
        print(f"{event['action']} action failed for {event['game_name']}! - {error}")
        info = f"Error: {error}"
    
    data = {
        "info": info
    }
    return json.dumps(data), 200, {'Content-Type': 'application/json'}