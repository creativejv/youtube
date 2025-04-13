#!/bin/bash

# Define color variables
BLACK_TEXT=$'\033[0;90m'
RED_TEXT=$'\033[0;91m'
GREEN_TEXT=$'\033[0;92m'
YELLOW_TEXT=$'\033[0;93m'
BLUE_TEXT=$'\033[0;94m'
MAGENTA_TEXT=$'\033[0;95m'
CYAN_TEXT=$'\033[0;96m'
WHITE_TEXT=$'\033[0;97m'

NO_COLOR=$'\033[0m'
RESET_FORMAT=$'\033[0m'
BOLD_TEXT=$'\033[1m'
UNDERLINE_TEXT=$'\033[4m'

clear

# Welcome message
echo "${BLUE_TEXT}${BOLD_TEXT}=======================================${RESET_FORMAT}"
echo "${BLUE_TEXT}${BOLD_TEXT}         INITIATING EXECUTION...  ${RESET_FORMAT}"
echo "${BLUE_TEXT}${BOLD_TEXT}=======================================${RESET_FORMAT}"
echo

echo -n "${YELLOW_TEXT}${BOLD_TEXT}Please enter the GCP region: ${RESET_FORMAT}"
read REGION
export REGION
export PROJECT_ID=`gcloud config get-value project`
export DATASET_ID=dataset1
export FHIR_STORE_ID=fhirstore1
export DICOM_STORE_ID=dicomstore1
export HL7_STORE_ID=hl7v2store1

echo "${MAGENTA_TEXT}${BOLD_TEXT}Enabling required services and configure your GCP environment.${RESET_FORMAT}"
echo

gcloud services enable compute.googleapis.com container.googleapis.com dataflow.googleapis.com bigquery.googleapis.com pubsub.googleapis.com healthcare.googleapis.com

echo "${GREEN_TEXT}${BOLD_TEXT}Step 1: Enabling required GCP services...${RESET_FORMAT}"

gcloud healthcare datasets create dataset1 --location=${REGION}

echo "${GREEN_TEXT}${BOLD_TEXT}Step 2: Creating Healthcare dataset...${RESET_FORMAT}"

sleep 30

PROJECT_NUMBER=$(gcloud projects describe $DEVSHELL_PROJECT_ID --format="value(projectNumber)")

SERVICE_ACCOUNT="service-${PROJECT_NUMBER}@gcp-sa-healthcare.iam.gserviceaccount.com"

echo "${GREEN_TEXT}${BOLD_TEXT}Step 3: Configuring IAM policy bindings for the service account...${RESET_FORMAT}"

gcloud projects add-iam-policy-binding $PROJECT_NUMBER \
  --member="serviceAccount:$SERVICE_ACCOUNT" \
  --role="roles/bigquery.admin"

gcloud projects add-iam-policy-binding $PROJECT_NUMBER \
  --member="serviceAccount:$SERVICE_ACCOUNT" \
  --role="roles/storage.objectAdmin"

gcloud projects add-iam-policy-binding $PROJECT_NUMBER \
  --member="serviceAccount:$SERVICE_ACCOUNT" \
  --role="roles/healthcare.datasetAdmin"

gcloud projects add-iam-policy-binding $PROJECT_NUMBER \
  --member="serviceAccount:$SERVICE_ACCOUNT" \
  --role="roles/pubsub.publisher"

echo "${GREEN_TEXT}${BOLD_TEXT}Step 4: Creating Pub/Sub topic and subscription...${RESET_FORMAT}"

gcloud pubsub topics create projects/$PROJECT_ID/topics/hl7topic

gcloud pubsub subscriptions create hl7_subscription --topic=hl7topic

echo "${GREEN_TEXT}${BOLD_TEXT}Step 5: Creating HL7v2 store and linking it to the Pub/Sub topic...${RESET_FORMAT}"

gcloud healthcare hl7v2-stores create $HL7_STORE_ID --dataset=$DATASET_ID --location=$REGION --notification-config=pubsub-topic=projects/$PROJECT_ID/topics/hl7topic

# Completion Message
echo
echo "${GREEN_TEXT}${BOLD_TEXT}=======================================================${RESET_FORMAT}"
echo "${GREEN_TEXT}${BOLD_TEXT}              LAB COMPLETED SUCCESSFULLY!              ${RESET_FORMAT}"
echo "${GREEN_TEXT}${BOLD_TEXT}=======================================================${RESET_FORMAT}"
echo

echo -e "${RED_TEXT}${BOLD_TEXT}Please Subscribe Creative JV:${RESET_FORMAT} ${BLUE_TEXT}${BOLD_TEXT}https://www.youtube.com/@creativejv${RESET_FORMAT}"
echo
