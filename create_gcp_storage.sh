
PROJECT_ID=$(gcloud config get-value project)

gsutil mb gs://${PROJECT_ID}-tfstate

gsutil versioning set on gs://${PROJECT_ID}-tfstate
