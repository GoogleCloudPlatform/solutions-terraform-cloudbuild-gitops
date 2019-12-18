BRANCH_NAME=$1
TF_STATE=$2

echo $BRANCH_NAME
echo $TF_STATE

SERV_IP=$(grep external_ip $TF_STATE | awk '{ print $3}')
echo "$SERV_IP"
[ "$SERV_IP" == "" ] && exit 1

RESPONSE=$(curl "http://$SERV_IP/" --connect-timeout 5)
echo "$RESPONSE"

[ "$RESPONSE" == "<html><body><h1>Environment: $BRANCH_NAME</h1></body></html>" ] || exit 1
