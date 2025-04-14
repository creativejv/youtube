echo "${BG_MAGENTA}${BOLD}Starting Execution${RESET}"

if [ -z "$ZONE" ]; then
    export ZONE=$(gcloud compute project-info describe --format="value(commonInstanceMetadata.items[google-compute-default-zone])")
    export REGION=$(echo "$ZONE" | cut -d '-' -f 1-2)
fi

gcloud services enable apikeys.googleapis.com || { echo "Failed to enable apikeys.googleapis.com"; exit 1; }

if [ ! -f endpoints-quickstart.zip ]; then
    gsutil cp gs://spls/gsp164/endpoints-quickstart.zip .
    unzip endpoints-quickstart.zip
fi

cd endpoints-quickstart/scripts || exit

./deploy_api.sh
./deploy_app.sh ../app/app_template.yaml $REGION
./query_api.sh JFK

# Introduce a delay to avoid exhausting quotas
sleep 1

gcloud alpha services api-keys create --display-name="awesome"
KEY_NAME=$(gcloud alpha services api-keys list --format="value(name)" --filter "displayName=awesome")
API_KEY=$(gcloud alpha services api-keys get-key-string $KEY_NAME --format="value(keyString)")

./query_api_with_key.sh $API_KEY
./generate_traffic_with_key.sh $API_KEY
sleep 1  # Add more delays if needed
./query_api_with_key.sh $API_KEY
