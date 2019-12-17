#!/bin/bash

BRANCH_NAME=$1
TF_STATE=$2

SERV_IP=$(terraform show | grep external_ip | awk '{ print $3}')
echo "$SERV_IP"
[ "$SERV_IP" == "" ] && exit 1

RESPONSE=$(curl "http://$SERV_IP/")
echo "$RESPONSE"

[ "$RESPONSE" == "<html><body><h1>Environment: $BRANCH_NAME</h1></body></html>" ] || exit 1
