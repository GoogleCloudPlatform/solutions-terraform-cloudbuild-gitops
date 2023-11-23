#!/bin/sh
if [ -d "environments/$BRANCH_NAME/" ]; then
        cd environments/$BRANCH_NAME
        terraform init
      else
        for dir in environments/*/
        do 
          cd ${dir}   
          env=${dir%*/}
          env=${env#*/}
          echo ""
          echo "*************** TERRAFORM INIT ******************"
          echo "******* At environment: ${env} ********"
          echo "*************************************************"
          terraform init || exit 1
          cd ../../
        done
      fi
      