from datetime import datetime
from dateutil.relativedelta import relativedelta

def client_age_validation(request):
    """Responds to any HTTP request.
    Args:
        request (flask.Request): HTTP request object.
    Returns:
        The response text or any set of values that can be turned into a
        Response object using
        `make_response <http://flask.pocoo.org/docs/1.0/api/#flask.Flask.make_response>`.
    """
    request_json = request.get_json()
    
    today = datetime.today()
    birth_date_str = request_json['data']['client']['birth_date']
    birth_date_obj = datetime.strptime(birth_date_str, '%Y-%m-%d')
    diff_years = relativedelta(today, birth_date_obj).years

    # Validação se idade > 18 e < 65
    result = True
    if diff_years < 18 or diff_years > 65:
        result = False

    request_json['data']['output'] = result

    return request_json
