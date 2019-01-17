#!/usr/bin/env bash
POSITIONAL=()
while [[ $# -gt 0 ]]
do
key="$1"

case $key in
    -c|--PKS_CLUSTER)
    CLUSTER="$2"
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

az network public-ip create \
 --resource-group ${ENV_NAME} \
 --name ${CLUSTER}-public-ip \
 --sku standard \
 --allocation-method static

az network lb create \
--resource-group ${ENV_NAME} \
--name ${CLUSTER}-lb \
--sku standard
--public-ip-address ${CLUSTER}-public-ip \
--frontend-ip-name ${CLUSTER}-fe \
--backend-pool-name ${CLUSTER}-be      

az network lb probe create \
--resource-group ${ENV_NAME} \
--lb-name ${CLUSTER}-lb \
--name ${CLUSTER}-probe-8443 \
--protocol tcp \
--port 8443

az network lb rule create \
--resource-group ${ENV_NAME} \
--lb-name ${CLUSTER}-lb \
--name rule_8443 \
--protocol tcp \
--frontend-port any \
--backend-port 8443 \
--frontend-ip-name ${CLUSTER}_fe \
--backend-pool-name ${CLUSTER}_be \
--probe-name ${CLUSTER}-probe-8443  