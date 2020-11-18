def effort_rate_new_credit_validation(request):
    """Responds to any HTTP request.
    Args:
        request (flask.Request): HTTP request object.
    Returns:
        The response text or any set of values that can be turned into a
        Response object using
        `make_response <http://flask.pocoo.org/docs/1.0/api/#flask.Flask.make_response>`.
    """
    request_json = request.get_json()

    if request_json.get('data').get('output') == False:
        return request_json
    
    # Validação da taxa de esforço contando com o novo crédito
    loan_amount = request_json.get('data').get('client').get('loan_amount')
    net_wage = request_json.get('data').get('client').get('net_wage')

    effort_rate = loan_amount / net_wage

    result = True
    if(effort_rate > 0.25):
        result = False
    
    request_json['data']['output'] = result

    return request_json
