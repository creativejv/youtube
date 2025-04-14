#!/bin/bash
# Define color variables
BLACK=`tput setaf 0`
RED=`tput setaf 1`
GREEN=`tput setaf 2`
YELLOW=`tput setaf 3`
BLUE=`tput setaf 4`
MAGENTA=`tput setaf 5`
CYAN=`tput setaf 6`
WHITE=`tput setaf 7`

BG_BLACK=`tput setab 0`
BG_RED=`tput setab 1`
BG_GREEN=`tput setab 2`
BG_YELLOW=`tput setab 3`
BG_BLUE=`tput setab 4`
BG_MAGENTA=`tput setab 5`
BG_CYAN=`tput setab 6`
BG_WHITE=`tput setab 7`

BOLD=`tput bold`
RESET=`tput sgr0`

#----------------------------------------------------start--------------------------------------------------#

echo "${BG_MAGENTA}${BOLD}Starting Execution${RESET}"

# Retry function with exponential backoff
retry_with_backoff() {
    local MAX_RETRIES=5
    local RETRY_COUNT=0
    local RETRY_DELAY=5  # Start with 5 seconds delay

    while [[ $RETRY_COUNT -lt $MAX_RETRIES ]]; do
        "$@" && return 0 || {
            RETRY_COUNT=$((RETRY_COUNT + 1))
            echo "${RED}Command failed. Retry ${RETRY_COUNT}/${MAX_RETRIES} after ${RETRY_DELAY}s...${RESET}"
            sleep $RETRY_DELAY
            RETRY_DELAY=$((RETRY_DELAY * 2))  # Double the delay on each retry
        }
    done
    echo "${BG_RED}${BOLD}Command failed after ${MAX_RETRIES} retries.${RESET}"
    return 1
}

# Retrieve the zone and region, if not already set
if [ -z "$ZONE" ]; then
    export ZONE=$(retry_with_backoff gcloud compute project-info describe \
    --format="value(commonInstanceMetadata.items[google-compute-default-zone])")
fi

export REGION=$(echo "$ZONE" | cut -d '-' -f 1-2)

# Enable the required service
echo "${YELLOW}Enabling apikeys.googleapis.com...${RESET}"
retry_with_backoff gcloud services enable apikeys.googleapis.com || {
    echo "${RED}Failed to enable apikeys.googleapis.com service${RESET}";
    exit 1;
}

# Prevent redundant downloads
if [ ! -f endpoints-quickstart.zip ]; then
    echo "${GREEN}Downloading and unzipping endpoints-quickstart.zip...${RESET}"
    retry_with_backoff gsutil cp gs://spls/gsp164/endpoints-quickstart.zip .
    unzip endpoints-quickstart.zip
fi

cd endpoints-quickstart || exit
cd scripts || exit

# Deploy API and App with necessary pauses to avoid quota exhaustion
echo "${CYAN}Deploying API and App...${RESET}"
retry_with_backoff ./deploy_api.sh
sleep 5
retry_with_backoff ./deploy_app.sh ../app/app_template.yaml $REGION
sleep 5

# Query API
echo "${CYAN}Querying API...${RESET}"
retry_with_backoff ./query_api.sh
sleep 5
retry_with_backoff ./query_api.sh JFK
sleep 5

# Deploy API with rate limit and redeploy the app
retry_with_backoff ./deploy_api.sh ../openapi_with_ratelimit.yaml
sleep 5
retry_with_backoff ./deploy_app.sh ../app/app_template.yaml $REGION
sleep 5

# Create API key and retrieve it
echo "${CYAN}Creating API key...${RESET}"
retry_with_backoff gcloud alpha services api-keys create --display-name="awesome"
KEY_NAME=$(retry_with_backoff gcloud alpha services api-keys list --format="value(name)" --filter "displayName=awesome")
export API_KEY=$(retry_with_backoff gcloud alpha services api-keys get-key-string $KEY_NAME --format="value(keyString)")

# Query API using the API key with delay to manage request rate
retry_with_backoff ./query_api_with_key.sh $API_KEY
sleep 5
retry_with_backoff ./generate_traffic_with_key.sh $API_KEY
sleep 5
retry_with_backoff ./query_api_with_key.sh $API_KEY

# Completion message
echo "${BG_RED}${BOLD}Congratulations For Completing The Lab Please Subscribe Creative JV !!!${RESET}"

#-----------------------------------------------------end----------------------------------------------------------#





