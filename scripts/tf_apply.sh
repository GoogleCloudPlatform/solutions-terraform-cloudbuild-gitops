#!/bin/sh
if [ -d "environments/$BRANCH_NAME/" ]; then
        cd environments/$BRANCH_NAME      
        terraform apply -auto-approve
      else
        echo "***************************** SKIPPING APPLYING *******************************"
        echo "Branch '$BRANCH_NAME' does not represent an official environment."
        echo "*******************************************************************************"
      fi