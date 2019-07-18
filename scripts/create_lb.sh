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
TOKEN=$(curl 'http://169.254.169.254/metadata/identity/oauth2/token?api-version=2018-02-01&resource=https%3A%2F%2Fvault.azure.net' -s -H Metadata:true | jq -r .access_token)
AZURE_SUBSCRIPTION_ID=$(curl -s -H Metadata:true "http://169.254.169.254/metadata/instance/compute?api-version=2017-08-01" | jq -r .subscriptionId)
AZURE_CLIENT_SECRET=$(curl https://${AZURE_VAULT}.vault.azure.net/secrets/AZURECLIENTSECRET?api-version=2016-10-01 -s -H "Authorization: Bearer ${TOKEN}" | jq -r .value)
AZURE_CLIENT_ID=$(curl https://${AZURE_VAULT}.vault.azure.net/secrets/AZURECLIENTID?api-version=2016-10-01 -s -H "Authorization: Bearer ${TOKEN}" | jq -r .value)
AZURE_TENANT_ID=$(curl https://${AZURE_VAULT}.vault.azure.net/secrets/AZURETENANTID?api-version=2016-10-01 -s -H "Authorization: Bearer ${TOKEN}" | jq -r .value)
PIVNET_UAA_TOKEN=$(curl https://${AZURE_VAULT}.vault.azure.net/secrets/PIVNETUAATOKEN?api-version=2016-10-01 -H "Authorization: Bearer ${TOKEN}" | jq -r .value)

az login --service-principal \
  --username ${AZURE_CLIENT_ID} \
  --password ${AZURE_CLIENT_SECRET} \
  --tenant ${AZURE_TENANT_ID}

az tag create --name K8SCLUSTER

az network public-ip create \
    --resource-group ${ENV_NAME} \
    --name ${CLUSTER}-public-ip \
    --sku standard \
    --tags K8SCLUSTER=${CLUSTER} \
    --allocation-method static

az network lb create \
    --resource-group ${ENV_NAME} \
    --name ${CLUSTER}-lb \
    --sku standard \
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
