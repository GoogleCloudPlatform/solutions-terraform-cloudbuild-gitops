import json
import googleapiclient.discovery

def mfa_status(self):
    # Get the list of users where 2FA is not enforced.
    users = get_users_where_2fa_not_enrolled(customer_id)
    users_found = []

    # Print the list of users.
    for user in users:
        print(user['name'])
        users_found.append(user['name'])
    
    # Return the list of users.
    if not users_found:
        return f'All users enrolled in MFA!'
    else:
        return json.dumps(users_found)

def get_users_where_2fa_not_enrolled(customer_id):
    # Create the Admin SDK Directory service object.
    service = googleapiclient.discovery.build('admin', 'directory_v1')

    # Set the query parameter to filter users where 2FA is not enforced.
    query = "isEnrolledIn2Sv=false"

    # Make the API call to get the list of users.
    users = service.users().list(customer=customer_id, query=query).execute()

    # Return the list of users.
    return users.get('users', [])