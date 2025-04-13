#!/bin/bash

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

echo "${BLUE_TEXT}${BOLD_TEXT}=======================================${RESET_FORMAT}"
echo "${BLUE_TEXT}${BOLD_TEXT}         INITIATING EXECUTION...  ${RESET_FORMAT}"
echo "${BLUE_TEXT}${BOLD_TEXT}=======================================${RESET_FORMAT}"
echo

echo -n "${YELLOW_TEXT}${BOLD_TEXT}Please enter the GCP region: ${RESET_FORMAT}"
read REGION
export REGION=$REGION
export PROJECT_ID=`gcloud config get-value project`
export DATASET_ID=dataset1
export DICOM_STORE_ID=dicomstore1

echo "${CYAN_TEXT}${BOLD_TEXT}Enabling required GCP services...${RESET_FORMAT}"
gcloud services enable compute.googleapis.com container.googleapis.com dataflow.googleapis.com bigquery.googleapis.com pubsub.googleapis.com healthcare.googleapis.com

echo "${MAGENTA_TEXT}${BOLD_TEXT}Creating a Cloud Healthcare dataset in the specified region...${RESET_FORMAT}"
gcloud healthcare datasets create dataset1 --location=$REGION

echo "${YELLOW_TEXT}${BOLD_TEXT}Waiting for 30 seconds to ensure dataset creation is completed...${RESET_FORMAT}"
sleep 30

echo "${CYAN_TEXT}${BOLD_TEXT}Fetching the current project ID...${RESET_FORMAT}"
export PROJECT_ID=$(gcloud config list --format 'value(core.project)')

echo "${CYAN_TEXT}${BOLD_TEXT}Fetching the project number for service account bindings...${RESET_FORMAT}"
export PROJECT_NUMBER=$(gcloud projects list --filter=projectId:$PROJECT_ID --format="value(projectNumber)")

echo "${GREEN_TEXT}${BOLD_TEXT}Granting BigQuery admin role to the Healthcare service account...${RESET_FORMAT}"
gcloud projects add-iam-policy-binding $PROJECT_ID --member=serviceAccount:service-$PROJECT_NUMBER@gcp-sa-healthcare.iam.gserviceaccount.com --role=roles/bigquery.admin

echo "${GREEN_TEXT}${BOLD_TEXT}Granting object admin role to allow access to storage objects...${RESET_FORMAT}"
gcloud projects add-iam-policy-binding $PROJECT_ID \
--member=serviceAccount:service-$PROJECT_NUMBER@gcp-sa-healthcare.iam.gserviceaccount.com \
--role=roles/storage.objectAdmin

echo "${GREEN_TEXT}${BOLD_TEXT}Granting dataset admin role to manage Healthcare datasets...${RESET_FORMAT}"
gcloud projects add-iam-policy-binding $PROJECT_ID \
--member=serviceAccount:service-$PROJECT_NUMBER@gcp-sa-healthcare.iam.gserviceaccount.com \
--role=roles/healthcare.datasetAdmin

echo "${GREEN_TEXT}${BOLD_TEXT}Granting DICOM store admin role for managing DICOM stores...${RESET_FORMAT}"
gcloud projects add-iam-policy-binding $PROJECT_ID \
--member=serviceAccount:service-$PROJECT_NUMBER@gcp-sa-healthcare.iam.gserviceaccount.com \
--role=roles/healthcare.dicomStoreAdmin

echo "${GREEN_TEXT}${BOLD_TEXT}Granting storage object creator role for uploading DICOM data to Cloud Storage...${RESET_FORMAT}"
gcloud projects add-iam-policy-binding $PROJECT_ID \
--member=serviceAccount:service-$PROJECT_NUMBER@gcp-sa-healthcare.iam.gserviceaccount.com \
--role=roles/storage.objectCreator

echo "${CYAN_TEXT}${BOLD_TEXT}Enabling DATA_READ and DATA_WRITE audit logging for Cloud Healthcare API...${RESET_FORMAT}"
gcloud projects get-iam-policy $PROJECT_ID > policy.yaml

echo "${MAGENTA_TEXT}${BOLD_TEXT}Appending audit logging configurations to the IAM policy file...${RESET_FORMAT}"
cat <<EOF >> policy.yaml
auditConfigs:
- auditLogConfigs:
  - logType: DATA_READ
  - logType: DATA_WRITE
  service: healthcare.googleapis.com
EOF

echo "${CYAN_TEXT}${BOLD_TEXT}Applying the updated IAM policy to enable audit logs...${RESET_FORMAT}"
gcloud projects set-iam-policy $PROJECT_ID policy.yaml

echo "${MAGENTA_TEXT}${BOLD_TEXT}Creating a DICOM store inside the previously created dataset...${RESET_FORMAT}"
gcloud beta healthcare dicom-stores create $DICOM_STORE_ID --dataset=$DATASET_ID --location=$REGION

echo "${CYAN_TEXT}${BOLD_TEXT}Using curl to create another DICOM store (dicomstore2) via REST API...${RESET_FORMAT}"
curl -X POST \
     -H "Authorization: Bearer "$(sudo gcloud auth print-access-token) \
     -H "Content-Type: application/json; charset=utf-8" \
"https://healthcare.googleapis.com/v1beta1/projects/$PROJECT_ID/locations/$REGION/datasets/$DATASET_ID/dicomStores?dicomStoreId=dicomstore2"

echo "${YELLOW_TEXT}${BOLD_TEXT}Pausing for 10 seconds to ensure store creation completes...${RESET_FORMAT}"
sleep 10

echo "${MAGENTA_TEXT}${BOLD_TEXT}Importing DICOM images from a public GCS bucket into the DICOM store...${RESET_FORMAT}"
gcloud beta healthcare dicom-stores import gcs $DICOM_STORE_ID --dataset=$DATASET_ID --location=$REGION --gcs-uri=gs://spls/gsp626/LungCT-Diagnosis/R_004/*

echo "${CYAN_TEXT}${BOLD_TEXT}De-identifying the imported DICOM data using the Healthcare API...${RESET_FORMAT}"
curl -X POST \
    -H "Authorization: Bearer "$(gcloud auth print-access-token) \
    -H "Content-Type: application/json; charset=utf-8" \
    --data "{
      'destinationDataset': 'projects/$PROJECT_ID/locations/$REGION/datasets/de-id',
      'config': {
        'dicom': {
          'filterProfile': 'ATTRIBUTE_CONFIDENTIALITY_BASIC_PROFILE'
        },
        'image': {
          'textRedactionMode': 'REDACT_NO_TEXT'
        }
      }
    }" "https://healthcare.googleapis.com/v1beta1/projects/$PROJECT_ID/locations/$REGION/datasets/$DATASET_ID:deidentify"

echo "${CYAN_TEXT}${BOLD_TEXT}Checking the status of the de-identification operation using the operation ID...${RESET_FORMAT}"
curl -X GET \
"https://healthcare.googleapis.com/v1beta1/projects/$PROJECT_ID/locations/$REGION/datasets/$DATASET_ID/operations/<operation-id>" \
-H "Authorization: Bearer "$(sudo gcloud auth print-access-token) \
-H 'Content-Type: application/json; charset=utf-8'

echo "${MAGENTA_TEXT}${BOLD_TEXT}Creating a new Cloud Storage bucket using the default project ID...${RESET_FORMAT}"
export BUCKET_ID="gs://$DEVSHELL_PROJECT_ID"
gsutil mb $BUCKET_ID

echo "${CYAN_TEXT}${BOLD_TEXT}Defining the Healthcare service account...${RESET_FORMAT}"
SERVICE_ACCOUNT="service-$PROJECT_NUMBER@gcp-sa-healthcare.iam.gserviceaccount.com"

echo "${GREEN_TEXT}${BOLD_TEXT}Granting the service account permission to upload objects into the GCS bucket...${RESET_FORMAT}"
gsutil iam ch serviceAccount:$SERVICE_ACCOUNT:roles/storage.objectCreator gs://$DEVSHELL_PROJECT_ID

echo "${MAGENTA_TEXT}${BOLD_TEXT}Exporting the DICOM store to GCS in JPEG format with a specific transfer syntax...${RESET_FORMAT}"
gcloud beta healthcare dicom-stores export gcs $DICOM_STORE_ID --dataset=$DATASET_ID --gcs-uri-prefix=$BUCKET_ID --mime-type="image/jpeg; transfer-syntax=1.2.840.10008.1.2.4.50" --location=$REGION

echo "${MAGENTA_TEXT}${BOLD_TEXT}Exporting the DICOM store to GCS in PNG format...${RESET_FORMAT}"
gcloud beta healthcare dicom-stores export gcs $DICOM_STORE_ID --dataset=$DATASET_ID --gcs-uri-prefix=$BUCKET_ID --mime-type="image/png" --location=$REGION

echo "${CYAN_TEXT}${BOLD_TEXT}Setting variables again in case script is reused later...${RESET_FORMAT}"
export PROJECT_ID=`gcloud config get-value project`
export DATASET_ID=dataset1
export DICOM_STORE_ID=dicomstore1

echo "${MAGENTA_TEXT}${BOLD_TEXT}Re-importing the same DICOM data to test roundtrip or reprocess...${RESET_FORMAT}"
gcloud beta healthcare dicom-stores import gcs $DICOM_STORE_ID --dataset=$DATASET_ID --location=$REGION --gcs-uri=gs://spls/gsp626/LungCT-Diagnosis/R_004/*

echo
echo "${GREEN_TEXT}${BOLD_TEXT}=======================================================${RESET_FORMAT}"
echo "${GREEN_TEXT}${BOLD_TEXT}              LAB COMPLETED SUCCESSFULLY!              ${RESET_FORMAT}"
echo "${GREEN_TEXT}${BOLD_TEXT}=======================================================${RESET_FORMAT}"
echo

echo -e "${RED_TEXT}${BOLD_TEXT}Please Subscribe Creative JV :${RESET_FORMAT} ${BLUE_TEXT}${BOLD_TEXT}https://www.youtube.com/@creativejv${RESET_FORMAT}"
echo
