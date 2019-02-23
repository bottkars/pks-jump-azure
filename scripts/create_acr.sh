#!/usr/bin/env bash
source .env.sh
MYSELF=$(basename $0)
mkdir -p ${LOG_DIR}/
exec &> >(tee -a "${LOG_DIR}//${MYSELF}.$(date '+%Y-%m-%d-%H').log")
exec 2>&1
POSITIONAL=()
while [[ $# -gt 0 ]]
do
key="$1"

case $key in
    -acr|--CONTAINER_REGISTRY_NAME)
    CONTAINER_REGISTRY_NAME="$2"
    shift # past argument
    shift # past value
    ;;
    *)    # unknown option
    POSITIONAL+=("$1") # save it in an array for later
    shift # past argument
    ;;
esac
done
set -- "${POSITIONAL[@]}" # restore positional parameters
source ~/.env.sh


az login --service-principal \
  --username ${AZURE_CLIENT_ID} \
  --password ${AZURE_CLIENT_SECRET} \
  --tenant ${AZURE_TENANT_ID}

az acr create --resource-group ${ENV_NAME} \
--name ${CONTAINER_REGISTRY_NAME} --sku Basic



ACR_LOGIN_SERVER=$(az acr list --resource-group ${ENV_NAME} \
    --query "[].{acrLoginServer:loginServer}" --output tsv)


az acr update --name ${CONTAINER_REGISTRY_NAME} --admin-enabled true
az acr credential show --name ${CONTAINER_REGISTRY_NAME} --query "passwords[0].value"
az acr login --name ${CONTAINER_REGISTRY_NAME}

