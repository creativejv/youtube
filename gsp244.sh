#!/bin/bash

# Define text colors and formatting
BLACK_TEXT=$(tput setaf 0)
RED_TEXT=$(tput setaf 1)
GREEN_TEXT=$(tput setaf 10) # Brighter Green
YELLOW_TEXT=$(tput setaf 3)
BLUE_TEXT=$(tput setaf 4)
MAGENTA_TEXT=$(tput setaf 5)
CYAN_TEXT=$(tput setaf 6)
WHITE_TEXT=$(tput setaf 7)

RESET_FORMAT=$(tput sgr0)
BOLD_TEXT=$(tput bold)
ITALIC_TEXT=$(tput sitm)
UNDERLINE_TEXT=$(tput smul)
clear # Clear the terminal screen

# --- Script Header ---
echo
echo "${BLUE_TEXT}${BOLD_TEXT}=======================================${RESET_FORMAT}"
echo "${BLUE_TEXT}${BOLD_TEXT} STARTING EXECUTION...Meanwhile Please Subscribe CreativeJV  ${RESET_FORMAT}"
echo "${BLUE_TEXT}${BOLD_TEXT}=======================================${RESET_FORMAT}"
echo

echo -n "${YELLOW_TEXT}${BOLD_TEXT}Please enter the zone: ${RESET_FORMAT}"
read ZONE
export ZONE

# Enable the required API
echo "${GREEN_TEXT}${BOLD_TEXT}Enabling the Filestore API...${RESET_FORMAT}"
gcloud services enable file.googleapis.com

# Create a Compute Engine instance
echo "${GREEN_TEXT}${BOLD_TEXT}Creating a Compute Engine instance named 'nfs-client'...${RESET_FORMAT}"
gcloud compute instances create nfs-client \
--project=$DEVSHELL_PROJECT_ID --zone=$ZONE --machine-type=e2-medium \
--network-interface=network-tier=PREMIUM,stack-type=IPV4_ONLY,subnet=default \
--metadata=enable-oslogin=true \
--maintenance-policy=MIGRATE \
--provisioning-model=STANDARD \
--scopes=https://www.googleapis.com/auth/devstorage.read_only,https://www.googleapis.com/auth/logging.write,https://www.googleapis.com/auth/monitoring.write,https://www.googleapis.com/auth/servicecontrol,https://www.googleapis.com/auth/service.management.readonly,https://www.googleapis.com/auth/trace.append --tags=http-server \
--create-disk=auto-delete=yes,boot=yes,device-name=nfs-client,image=projects/debian-cloud/global/images/debian-11-bullseye-v20231010,mode=rw,size=10,type=projects/$DEVSHELL_PROJECT_ID/zones/$ZONE/diskTypes/pd-balanced --no-shielded-secure-boot --shielded-vtpm --shielded-integrity-monitoring --labels=goog-ec-src=vm_add-gcloud --reservation-affinity=any

# Create a Filestore instance
echo "${GREEN_TEXT}${BOLD_TEXT}Creating a Filestore instance named 'nfs-server'...${RESET_FORMAT}"
gcloud filestore instances create nfs-server \
--zone=$ZONE --tier=BASIC_HDD \
--file-share=name="vol1",capacity=1TB \
--network=name="default"

# Final message
echo -e "${RED_TEXT}${BOLD_TEXT}Subscribe Creative JV:${RESET_FORMAT} ${BLUE_TEXT}${BOLD_TEXT}https://www.youtube.com/@creativejv${RESET_FORMAT}"
echo
