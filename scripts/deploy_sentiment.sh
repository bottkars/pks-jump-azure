#!/usr/bin/env bash
source .env.sh
IMAGE_NAME="mcr.microsoft.com/azure-cognitive-services/sentiment:latest"
docker pull ${IMAGE_NAME}

HARBOR_IMAGE_NAME="harbor.${PKS_SUBDOMAIN_NAME}.${PKS_DOMAIN_NAME}/library/sentiment:latest"
IMAGE_ID=$(docker images --format="{{.Repository}} {{.ID}}" |  grep "azure-cognitive" |  cut -d' ' -f2)
docker tag ${IMAGE_ID} ${HARBOR_IMAGE_NAME}
docker push ${HARBOR_IMAGE_NAME}

