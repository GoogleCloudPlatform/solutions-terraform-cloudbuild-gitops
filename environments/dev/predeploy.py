# Copyright 2024 Acalvio Technologies, Inc.

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
import requests
import sys
def perform_pre_deployment(ADC_URL_HASH,SESSION_ID,SERVICE_ACCOUNT,ADC_LB_ADDRESS):
    # Populate the hash in the URL's query parameters
    try:
        params = {
            'sigHash': ADC_URL_HASH,
        }
        # Craft the body
        body = {
            "sid": SESSION_ID,
            "iam-bindings": [
                {
                    "sa": SERVICE_ACCOUNT,
                    "allow": ["roles/compute.imageUser"],
                    "revoke": [],
                },
            ],
        }
        url = "https://" + ADC_LB_ADDRESS + "/gcp/sensor-deployment/pre-deploy"
        
        response = requests.post(url, json=body, params=params, timeout=180, verify=False)
        if response.status_code != 200:
            raise Exception(response.status_code)
    except Exception as e:
        print(e)
        return 1
    return 0

if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--adc_url_hash', 
                        help='ADC\'s URL hash',
                        required=True)
    parser.add_argument('--session_id',
                            help='Session ID',
                            required=True)
    parser.add_argument('--service_account',
                    help='Project service account',
                    required=True)
    parser.add_argument('--adc_lb_address',
                            help='ADC\'s LB Address',
                            required=True)
    args = parser.parse_args()
    rc = perform_pre_deployment(args.adc_url_hash,args.session_id,args.service_account,args.adc_lb_address)
    exit(rc)
    #exit(1)
        
        
        
        
