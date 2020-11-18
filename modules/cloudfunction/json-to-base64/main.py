import base64
import json

def json_to_base64(request):
    """Responds to any HTTP request.
    Args:
        request (flask.Request): HTTP request object.
    Returns:
        The response text or any set of values that can be turned into a
        Response object using
        `make_response <http://flask.pocoo.org/docs/1.0/api/#flask.Flask.make_response>`.
    """
    request_json = request.get_json()

    base64_bytes = base64.b64encode(json.dumps(request_json).encode('utf-8'))

    return base64_bytes
