# Steps

## Create Terraform Bucket and enabling versioning
```
export PROJECT_ID=$(gcloud config get-value project)
export BUCKET_NAME=${PROJECT_ID}-terraform

gsutil mb gs://${BUCKET_NAME} 
gsutil versioning set on gs://${BUCKET_NAME}
```

## Modify terraform.tfvars and backend.tf, with the PROJECT ID
```
cd ~/solutions-terraform-cloudbuild-gitops
sed -i s/PROJECT_ID/$PROJECT_ID/g environments/*/terraform.tfvars
sed -i s/PROJECT_ID/$PROJECT_ID/g environments/*/backend.tf
```
in mac
```
sed -i "" s/PROJECT_ID/$PROJECT_ID/g environments/*/terraform.tfvars
sed -i "" s/PROJECT_ID/$PROJECT_ID/g environments/*/backend.tf
```

## Update Git
git add --all
git commit -m "Update project IDs and buckets"
git push origin dev



## Grant Cloud Build Service Account with Editor Role
CLOUDBUILD_SA="$(gcloud projects describe $PROJECT_ID \
    --format 'value(projectNumber)')@cloudbuild.gserviceaccount.com"
gcloud projects add-iam-policy-binding $PROJECT_ID \
    --member serviceAccount:$CLOUDBUILD_SA --role roles/editor


## Directly connect Cloud Build to GitHub repo
open https://github.com/marketplace/google-cloud-build
click "Setup with Google Cloud Build" 
choose: Only select repositories and select this repo

In GCP Console, go to trigger, create new trigger in specific project and zone
in Source, Select Source:  GitHub, Authenticate, Fill Account and Repository.
Branch .*, use service account CLOUDBUILD_SA.







