#!/bin/sh
if [ -d "environments/$BRANCH_NAME/" ]; then
        cd environments/$BRANCH_NAME
        terraform plan
      else
        for dir in environments/*/
        do 
          cd ${dir}   
          env=${dir%*/}
          env=${env#*/}  
          echo ""
          echo "*************** TERRAFOM PLAN ******************"
          echo "******* At environment: ${env} ********"
          echo "*************************************************"
          terraform plan || exit 1
          cd ../../
        done
      fi 