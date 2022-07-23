import json

def admin_access():
    print("heya, this works!")
    return {
            'statusCode': 200,
            'body': json.dumps("worked!")
        }