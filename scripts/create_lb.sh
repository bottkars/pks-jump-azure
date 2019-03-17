#!/usr/bin/env bash
source .env.sh
MYSELF=$(basename $0)
mkdir -p ${LOG_DIR}/
exec &> >(tee -a "${LOG_DIR}/${MYSELF}.$(date '+%Y-%m-%d-%H').log")
exec 2>&1
POSITIONAL=()
while [[ $# -gt 0 ]]
do
key="$1"

case $key in
    -c|--K8S_CLUSTER_NAME)
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

if  [ -z ${CLUSTER} ] ; then
 echo "Please specify K8S Cluster Name with -c|--K8S_CLUSTER_NAME"
 exit 1
fi 

source ~/.env.sh

az login --service-principal \
  --username ${AZURE_CLIENT_ID} \
  --password ${AZURE_CLIENT_SECRET} \
  --tenant ${AZURE_TENANT_ID}

az tag create --name K8SCLUSTER

az network public-ip create \
    --resource-group ${ENV_NAME} \
    --name ${CLUSTER}-public-ip \
    --sku basic \
    --tags K8SCLUSTER=${CLUSTER} \
    --allocation-method static

az network lb create \
    --resource-group ${ENV_NAME} \
    --name ${CLUSTER}-lb \
    --sku basic \
    --tags K8SCLUSTER=${CLUSTER} \
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
    --frontend-port 8443 \
    --backend-port 8443 \
    --frontend-ip-name ${CLUSTER}-fe \
    --backend-pool-name ${CLUSTER}-be \
    --probe-name ${CLUSTER}-probe-8443

AZURE_LB_PUBLIC_IP=$(az network public-ip show \
    --resource-group ${ENV_NAME} \
    --name ${CLUSTER}-public-ip \
    --query "{address: ipAddress}" \
    --output tsv)

az network dns record-set a create \
    --resource-group ${ENV_NAME} \
    --zone-name ${PKS_SUBDOMAIN_NAME}.${PKS_DOMAIN_NAME} \
    --name ${CLUSTER} --ttl 60

az network dns record-set a add-record \
    --resource-group ${ENV_NAME} \
    --zone-name ${PKS_SUBDOMAIN_NAME}.${PKS_DOMAIN_NAME} \
    --record-set-name ${CLUSTER} \
    --ipv4-address ${AZURE_LB_PUBLIC_IP}
