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

# Instruction for authentication
echo "${CYAN_TEXT}${BOLD_TEXT}Step 1:${RESET_FORMAT} Authenticating with Google Cloud..."
gcloud auth list

# Instruction for enabling services
echo "${CYAN_TEXT}${BOLD_TEXT}Step 2:${RESET_FORMAT} Enabling required Google Cloud services..."
gcloud services enable cloudscheduler.googleapis.com
gcloud services enable run.googleapis.com

sleep 15

# Instruction for setting up region and zone
echo "${CYAN_TEXT}${BOLD_TEXT}Step 3:${RESET_FORMAT} Setting up default region and zone..."
export ZONE=$(gcloud compute project-info describe --format="value(commonInstanceMetadata.items[google-compute-default-zone])")
export REGION=$(gcloud compute project-info describe --format="value(commonInstanceMetadata.items[google-compute-default-region])")

# Instruction for downloading and navigating to the working directory
echo "${CYAN_TEXT}${BOLD_TEXT}Step 4:${RESET_FORMAT} Downloading required files and navigating to the working directory..."
gcloud storage cp -r gs://spls/gsp649/* . && cd gcf-automated-resource-cleanup/

# Instruction for setting project ID
echo "${CYAN_TEXT}${BOLD_TEXT}Step 5:${RESET_FORMAT} Setting up the project ID..."
export PROJECT_ID=$(gcloud config list --format 'value(core.project)' 2>/dev/null)
WORKDIR=$(pwd)

# Instruction for installing dependencies
echo "${CYAN_TEXT}${BOLD_TEXT}Step 6:${RESET_FORMAT} Installing required dependencies..."
sudo apt-get update
sudo apt-get install apache2-utils -y

# Instruction for creating a serving bucket
echo "${CYAN_TEXT}${BOLD_TEXT}Step 7:${RESET_FORMAT} Creating a serving bucket..."
cd $WORKDIR/migrate-storage
export PROJECT_ID=$(gcloud config list --format 'value(core.project)' 2>/dev/null)
gcloud storage buckets create  gs://${PROJECT_ID}-serving-bucket -l $REGION

# Instruction for setting bucket permissions
echo "${CYAN_TEXT}${BOLD_TEXT}Step 8:${RESET_FORMAT} Setting public read permissions for the serving bucket..."
gsutil acl ch -u allUsers:R gs://${PROJECT_ID}-serving-bucket

# Instruction for uploading a test file
echo "${CYAN_TEXT}${BOLD_TEXT}Step 9:${RESET_FORMAT} Uploading a test file to the serving bucket..."
gcloud storage cp $WORKDIR/migrate-storage/testfile.txt  gs://${PROJECT_ID}-serving-bucket

# Instruction for verifying file upload
echo "${CYAN_TEXT}${BOLD_TEXT}Step 10:${RESET_FORMAT} Verifying the uploaded file..."
gsutil acl ch -u allUsers:R gs://${PROJECT_ID}-serving-bucket/testfile.txt
curl http://storage.googleapis.com/${PROJECT_ID}-serving-bucket/testfile.txt

# Instruction for creating an idle bucket
echo "${CYAN_TEXT}${BOLD_TEXT}Step 11:${RESET_FORMAT} Creating an idle bucket..."
gcloud storage buckets create gs://${PROJECT_ID}-idle-bucket -l $REGION
export IDLE_BUCKET_NAME=$PROJECT_ID-idle-bucket

# Instruction for enabling monitoring
echo "${CYAN_TEXT}${BOLD_TEXT}Step 12:${RESET_FORMAT} Enabling monitoring services..."
gcloud services enable monitoring.googleapis.com

# Instruction for creating a monitoring dashboard
echo "${CYAN_TEXT}${BOLD_TEXT}Step 13:${RESET_FORMAT} Creating a monitoring dashboard for bucket usage..."
cat > bucket_usage_dashboard.json <<EOF_CP
{
  "displayName": "Bucket Usage",
  "gridLayout": {
    "columns": 1,
    "widgets": [
      {
        "title": "Bucket Access",
        "xyChart": {
          "dataSets": [
            {
              "timeSeriesQuery": {
                "timeSeriesFilter": {
                  "filter": "metric.type=\"storage.googleapis.com/api/request_count\" AND metric.label.method=\"ReadObject\"",
                  "aggregation": {
                    "alignmentPeriod": "60s",
                    "perSeriesAligner": "ALIGN_RATE"
                  }
                }
              }
            }
          ],
          "timeshiftDuration": "0s",
          "yAxis": {
            "label": "Request Count",
            "scale": "LINEAR"
          }
        }
      }
    ]
  }
}
EOF_CP

gcloud monitoring dashboards create --config-from-file=bucket_usage_dashboard.json

# Instruction for testing idle bucket
echo "${CYAN_TEXT}${BOLD_TEXT}Step 14:${RESET_FORMAT} Testing the idle bucket..."
echo "Test content" > testfile.txt
gsutil cp testfile.txt gs://$PROJECT_ID-idle-bucket/
gsutil cat gs://$PROJECT_ID-idle-bucket/testfile.txt

# Instruction for enabling Cloud Run
echo "${CYAN_TEXT}${BOLD_TEXT}Step 15:${RESET_FORMAT} Enabling Cloud Run services..."
gcloud services enable run.googleapis.com

# Instruction for modifying and deploying the function
echo "${CYAN_TEXT}${BOLD_TEXT}Step 16:${RESET_FORMAT} Modifying and deploying the Cloud Function..."
cat $WORKDIR/migrate-storage/main.py | grep "migrate_storage(" -A 15
sed -i "s/<project-id>/$PROJECT_ID/" $WORKDIR/migrate-storage/main.py

# Instruction for disabling and re-enabling Cloud Functions
echo "${CYAN_TEXT}${BOLD_TEXT}Step 17:${RESET_FORMAT} Disabling and re-enabling Cloud Functions..."
gcloud services disable cloudfunctions.googleapis.com
gcloud services enable cloudfunctions.googleapis.com

# Instruction for setting IAM policy
echo "${CYAN_TEXT}${BOLD_TEXT}Step 18:${RESET_FORMAT} Setting IAM policy for the project..."
export PROJECT_NUMBER=$(gcloud projects describe $PROJECT_ID --format="value(projectNumber)")
gcloud projects add-iam-policy-binding $PROJECT_ID \
--member="serviceAccount:$PROJECT_NUMBER-compute@developer.gserviceaccount.com" \
--role="roles/artifactregistry.reader"

# Instruction for deploying the function
echo "${CYAN_TEXT}${BOLD_TEXT}Step 19:${RESET_FORMAT} Deploying the Cloud Function..."
export REGION=$(gcloud compute project-info describe --format="value(commonInstanceMetadata.items[google-compute-default-region])")
export PROJECT_ID=$(gcloud config get-value project)
export WORKDIR=~/gcf-automated-resource-cleanup
cd $WORKDIR/migrate-storage

SERVICE_NAME="migrate_storage"

deploy_function() {
  gcloud functions deploy migrate_storage \
  --gen2 \
  --region=$REGION \
  --runtime=python39 \
  --entry-point=migrate_storage \
  --trigger-http \
  --source=. \
  --quiet
}

while true; do
  deploy_function
  if gcloud functions describe $SERVICE_NAME --region $REGION &> /dev/null; then
    echo ""
    break
  else
    echo ""
    sleep 10
  fi
done

sleep 10

# Instruction for setting up the function URL
echo "${CYAN_TEXT}${BOLD_TEXT}Step 20:${RESET_FORMAT} Setting up the function URL..."
export FUNCTION_URL=$(gcloud functions describe migrate_storage --format=json --region $REGION | jq -r '.url')

export IDLE_BUCKET_NAME=$PROJECT_ID-idle-bucket
sed -i "s/\\\$IDLE_BUCKET_NAME/$IDLE_BUCKET_NAME/" $WORKDIR/migrate-storage/incident.json

envsubst < $WORKDIR/migrate-storage/incident.json | curl -X POST -H "Content-Type: application/json" $FUNCTION_URL -d @-

# Instruction for setting storage class
echo "${CYAN_TEXT}${BOLD_TEXT}Step 21:${RESET_FORMAT} Setting the storage class for the idle bucket..."
gsutil defstorageclass set nearline gs://$PROJECT_ID-idle-bucket
gsutil defstorageclass get gs://$PROJECT_ID-idle-bucket

# Completion Message
echo
echo "${GREEN_TEXT}${BOLD_TEXT}=======================================================${RESET_FORMAT}"
echo "${GREEN_TEXT}${BOLD_TEXT}              LAB COMPLETED SUCCESSFULLY!              ${RESET_FORMAT}"
echo "${GREEN_TEXT}${BOLD_TEXT}=======================================================${RESET_FORMAT}"
echo ""
echo -e "${RED_TEXT}${BOLD_TEXT}Subscribe Creative JV:${RESET_FORMAT} ${BLUE_TEXT}${BOLD_TEXT}https://www.youtube.com/@creativejv${RESET_FORMAT}"
echo
