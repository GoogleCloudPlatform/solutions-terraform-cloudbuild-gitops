#!/bin/bash
#set -e
# NOTE: execute this from project root

# config
region='us-east1'
zone=$region"-a"
hazone=$region"-b"
drregion='us-east1'   #eg. us-east1 (b,c and d are valid)
drzone=$drregion"-b"

#Generate a unique prefix for the bucket
uniq=$(head /dev/urandom | LC_ALL=C  tr -dc a-z | head -c10)

project='sky-sada-ml'
projectNumber=891104928568

#differentiate this deployment from others. Use lowercase alphanumerics up to 8 characters.
prefix='mssqldev'

#domain name (this will have .com added to make it fully qualified)
domainName='dev-domain'

#user you will be running as (a fully google or gmail email address)
user='skyler.moore-firkins@sada.com'

# NOTE: execute this from project root
tf_path='environments/dev'
scripts_path='scripts'
#######################################################################################
### For the purposes of this demo script, you dont need to fill in anything past here
#######################################################################################

#bucket where your terraform state file, passwords and outputs will be stored
bucketName=$uniq'-deployment-staging'

kmsKeyRing=$prefix"-deployment-ring"
kmsKey=$prefix"-deployment-key"

echo $prefix
echo $bucketName
echo $kmsKeyRing
echo $kmsKey

# The files we have to substitute in are:
# backend.tf  clearwaiters.sh  copyBootstrapArtifacts.sh  getDomainPassword.sh  main.tf
sed -i '' "s/{common-backend-bucket}/$bucketName/g;s/{windows-domain}/$domainName/g;s/{cloud-project-id}/$project/g;s/{cloud-project-region}/$region/g;s/{cloud-project-zone}/$zone/g;s/{cloud-project-hazone}/$hazone/g;s/{cloud-project-drregion}/$drregion/g;s/{cloud-project-drzone}/$drzone/g;s/{deployment-name}/$prefix/g" "$tf_path/backend.tf" "$tf_path/main.tf" "$scripts_path/clearwaiters.sh" "$scripts_path/copyBootstrapArtifacts.sh" "$scripts_path/getDomainPassword.sh"
 
#########################################
#enable the services that we depend upon
##########################################
 for API in compute cloudkms deploymentmanager runtimeconfig cloudresourcemanager iam storage-api storage-component
 do
         gcloud services enable "$API.googleapis.com" --project $project
 done
 
#create the bucket
 gsutil mb -p $project gs://$bucketName
 gsutil -m cp -r powershell/bootstrap/* gs://$bucketName/powershell/bootstrap/
 
DefaultServiceAccount="$projectNumber-compute@developer.gserviceaccount.com"
AdminServiceAccountName="admin-$prefix"
echo AdminServiceAccountName
 
AdminServiceAccount="$AdminServiceAccountName@$project.iam.gserviceaccount.com"
echo $AdminServiceAccount
 
gcloud iam service-accounts create $AdminServiceAccountName --display-name "Admin service account for bootstrapping domain-joined servers with elevated permissions" --project $project
gcloud iam service-accounts add-iam-policy-binding $AdminServiceAccount --member "user:$user" --role "roles/iam.serviceAccountUser" --project $project
gcloud projects add-iam-policy-binding $project --member "serviceAccount:$AdminServiceAccount" --role "roles/editor"
 
ServiceAccount=$AdminServiceAccount
echo  "Service Account: [$ServiceAccount]"
 
 
 gcloud kms keyrings create $kmsKeyRing --project $project --location $region
 gcloud kms keys create $kmsKey --project $project --purpose=encryption --keyring $kmsKeyRing --location $region
 
 sed "s/{Usr}/$user/g;s/{SvcAccount}/$ServiceAccount/g" $scripts_path/policy.json | tee policy.out
 echo $policy
 
 
 gcloud kms keys set-iam-policy $kmsKey policy.out --project $project --location=$region --keyring=$kmsKeyRing
 rm policy.out
 
 
 sed "s/{Usr}/$user/g;s/{SvcAccount}/$DefaultServiceAccount/g" $scripts_path/policy.json | tee policy.out
 gcloud kms keys set-iam-policy $kmsKey policy.out --project $project --location=$region --keyring=$kmsKeyRing
 rm policy.out


