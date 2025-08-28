#!/bin/bash
#
# Creates workload image and publishes the workload image to artifact repository.

PRIMUS_PROJECT_ID=primus-bank-421307
SECUNDUS_PROJECT_ID=secundus-bank-421307
REGION=us-central1

PARENT_DIR=$(dirname ${PWD})
PRIMUS_PROJECT_NUMBER=$(gcloud projects describe ${PRIMUS_PROJECT_ID} --format="value(projectNumber)")
SECUNDUS_PROJECT_NUMBER=$(gcloud projects describe ${SECUNDUS_PROJECT_ID} --format="value(projectNumber)")
IMAGE_REFERENCE=${REGION}-docker.pkg.dev/${PRIMUS_PROJECT_ID}/${PRIMUS_PROJECT_ID}-repo/workload-container:latest

gcloud config set project ${PRIMUS_PROJECT_ID}

gcloud auth configure-docker ${REGION}-docker.pkg.dev

echo "Updating workload code with required resource names ..."
./generate_workload_code.sh
sed -i'' "s/PRIMUS_INPUT_STORAGE_BUCKET/${PRIMUS_PROJECT_ID}-input-bucket/" ${PARENT_DIR}/src/workload.go
sed -i'' "s/PRIMUS_PROJECT_ID/${PRIMUS_PROJECT_ID}/" ${PARENT_DIR}/src/workload.go
sed -i'' "s/PRIMUS_ENC_KEYRING/${PRIMUS_PROJECT_ID}-sym-enc-kr/" ${PARENT_DIR}/src/workload.go
sed -i'' "s/PRIMUS_ENC_KEY/${PRIMUS_PROJECT_ID}-sym-enc-key/" ${PARENT_DIR}/src/workload.go
sed -i'' "s/PRIMUS_SERVICE_ACCOUNT/${PRIMUS_PROJECT_ID}-sa/" ${PARENT_DIR}/src/workload.go
sed -i'' "s/PRIMUS_WORKLOAD_IDENTITY_POOL/${PRIMUS_PROJECT_ID}-pool/" ${PARENT_DIR}/src/workload.go
sed -i'' "s/PRIMUS_WIP_PROVIDER/${PRIMUS_PROJECT_ID}-provider/" ${PARENT_DIR}/src/workload.go
sed -i'' "s/PRIMUS_PROJECT_NUMBER/${PRIMUS_PROJECT_NUMBER}/" ${PARENT_DIR}/src/workload.go

sed -i'' "s/global\/keyRings/${REGION}\/keyRings/" ${PARENT_DIR}/src/workload.go

sed -i'' "s/SECUNDUS_INPUT_STORAGE_BUCKET/${SECUNDUS_PROJECT_ID}-input-bucket/" ${PARENT_DIR}/src/workload.go
sed -i'' "s/SECUNDUS_PROJECT_ID/${SECUNDUS_PROJECT_ID}/" ${PARENT_DIR}/src/workload.go
sed -i'' "s/SECUNDUS_ENC_KEYRING/${SECUNDUS_PROJECT_ID}-sym-enc-kr/" ${PARENT_DIR}/src/workload.go
sed -i'' "s/SECUNDUS_ENC_KEY/${SECUNDUS_PROJECT_ID}-sym-enc-key/" ${PARENT_DIR}/src/workload.go
sed -i'' "s/SECUNDUS_SERVICE_ACCOUNT/${SECUNDUS_PROJECT_ID}-sa/" ${PARENT_DIR}/src/workload.go
sed -i'' "s/SECUNDUS_WORKLOAD_IDENTITY_POOL/${SECUNDUS_PROJECT_ID}-pool/" ${PARENT_DIR}/src/workload.go
sed -i'' "s/SECUNDUS_WIP_PROVIDER/${SECUNDUS_PROJECT_ID}-provider/" ${PARENT_DIR}/src/workload.go
sed -i'' "s/SECUNDUS_PROJECT_NUMBER/${SECUNDUS_PROJECT_NUMBER}/" ${PARENT_DIR}/src/workload.go

echo "Building the workload go binary ..."
cd ${PARENT_DIR}/src
go mod init workload && go mod tidy
CGO_ENABLED=0 go build workload.go

echo "Building the workload docker image ..."
docker build . -t ${IMAGE_REFERENCE}
cd ${PARENT_DIR}/scripts

echo "Pushing the workload docker image to artifact registry ${PRIMUS_PROJECT_ID}-repo ..."
docker push ${IMAGE_REFERENCE}
