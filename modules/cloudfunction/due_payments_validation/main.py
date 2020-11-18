from google.cloud import bigquery

def due_payments_validation(request):
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
    
    client = bigquery.Client()

    query = "SELECT 1 FROM bank.monthly_payments WHERE cc_number_id like '''" + request_json['data']['client']['cc_number_id'] + "''' AND has_due_payments = TRUE;"
    print(query.rstrip())
    query_job = client.query(query)

    results = query_job.result()

    result = True
    if(results.total_rows > 0):
        result = False
    
    request_json['data']['output'] = result

    return request_json
