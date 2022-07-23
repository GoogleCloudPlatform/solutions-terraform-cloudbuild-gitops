import json

def admin_access(request):
    print("heya, this works!")
    return {
            'statusCode': 200,
            'body': json.dumps("worked!")
        }