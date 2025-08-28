# Copyright 2024 Acalvio Technologies, Inc.

from googleapiclient import errors
import argparse
import json
import logging
import os
import random
import time
import uuid
import urllib3
import warnings
from collections import Counter, defaultdict
from googleapiclient import discovery
import requests  
import sys, json
from google.cloud import securitycenter  

def get_cscc_source(client,org_id,name): 
    org_str = 'organizations/' + org_id
    try:
        res = client.organizations().sources().list(parent=org_str).execute()
    except errors.HttpError as err:
        print('Error querying sources for CSCC in {}: {}'
                                  ''.format(org_id, err))
        return 1
    if 'sources' not in res:
        return None
    for source in res['sources']:
        if source['displayName'] == name:
            return source
    return None
if __name__ == '__main__':
    #get client
    client = securitycenter.SecurityCenterClient()
    data = json.load(sys.stdin)
    for i in data:
        if i == "name":
            name = i
        if i == "org_id":
            org_id = i
    
    source = get_cscc_source(client,org_id,name)
    if source == 1:    
        exit(source)
    result = json.dumps(source)
    print(result, file = sys.stdout)
    #exit(1)
