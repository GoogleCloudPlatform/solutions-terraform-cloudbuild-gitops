# Managing infrastructure as code with Terraform, Cloud Build, and GitOps

This is the repo for the [Managing infrastructure as code with Terraform, Cloud Build, and GitOps](https://cloud.google.com/solutions/managing-infrastructure-as-code) tutorial. This tutorial explains how to manage infrastructure as code with Terraform and Cloud Build using the popular GitOps methodology. 

## Configuring your **dev** environment

Just for demostration, this step will:
 1. Configure an apache2 http server on network '**dev**' and subnet '**dev**-subnet-01'
 2. Open port 80 on firewall for this http server 

```bash
cd ../environments/dev
terraform init
terraform plan
terraform apply
terraform destroy
```

## Promoting your environment to **production**

Once you have tested your app (in this example an apache2 http server), you can promote your configuration to prodution. This step will:
 1. Configure an apache2 http server on network '**prod**' and subnet '**prod**-subnet-01'
 2. Open port 80 on firewall for this http server 

```bash
cd ../prod
terraform init
terraform plan
terraform apply
terraform destroy
```

## Objective
- Set up your GitHub repository.
- Configure Terraform to store state in a Cloud Storage bucket.
- Grant permissions to your Cloud Build service account.
- Connect Cloud Build to your GitHub repository.
- Change your environment configuration in a feature branch.
- Promote changes to the development environment.
- Promote changes to the production environment.

## what is backend?
    - where to store terraform state data remotely, allow multiple people to work on the same terraform project
    - reference link: https://developer.hashicorp.com/terraform/language/settings/backends/configuration
    - in this example, we learn about how to config terraform backend with gcp cloud storage bucket

## using steam editor (sed) command to replace or substitute 
- sed -i s/PROJECT_ID/$PROJECT_ID/g environments/*/terraform.tfvars
- sed -i s/PROJECT_ID/$PROJECT_ID/g environments/*/backend.tf

## grant editor role for cloud build service account
- cloud build have a special default service account
- get cloud build sa with command: CLOUDBUILD_SA="$(gcloud projects describe $PROJECT_ID \
    --format 'value(projectNumber)')@cloudbuild.gserviceaccount.com"
- grant default cloud build service account with editor role: gcloud projects add-iam-policy-binding $PROJECT_ID \
    --member serviceAccount:$CLOUDBUILD_SA --role roles/editor

## directly connect cloud build with github
- follow the intruction from reference link to connect cloudbuild with github
- create trigger which listen to change change in all branch or a specific brand
