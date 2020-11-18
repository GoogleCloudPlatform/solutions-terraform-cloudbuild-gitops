from google.cloud import bigquery
from decimal import Decimal

def effort_rate_total_credit_validation(request):
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

    query = "SELECT monthly_payment_amout FROM bank.monthly_payments WHERE cc_number_id like '''" + request_json['data']['client']['cc_number_id'] + "''';"

    query_job = client.query(query)

    results = query_job.result()

    # Validação da taxa de esforço contando com todos os créditos
    loan_amount = Decimal(request_json.get('data').get('client').get('loan_amount'))
    net_wage = Decimal(request_json.get('data').get('client').get('net_wage'))
    monthly_payment_amout = 0

    for row in results:
        monthly_payment_amout = row.monthly_payment_amout

    effort_rate = (loan_amount + monthly_payment_amout) / net_wage

    result = True
    if(effort_rate > 0.4):
        result = False
    
    request_json['data']['output'] = result

    return request_json
