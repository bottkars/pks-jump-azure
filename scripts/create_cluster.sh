#!/usr/bin/env bash
source .env.sh
MYSELF=$(basename $0)
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
    -p|--PLAN_NAME)
    PLAN_NAME="$2"
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
if  [ -z ${PLAN_NAME} ] ; then
 echo "Please specify PKS PLAN Name with -p|--PLAN_NAME"
 exit 1
fi 
source ~/.env.sh
TOKEN=$(curl 'http://169.254.169.254/metadata/identity/oauth2/token?api-version=2018-02-01&resource=https%3A%2F%2Fvault.azure.net' -s -H Metadata:true | jq -r .access_token)
PIVNET_UAA_TOKEN=$(curl https://${AZURE_VAULT}.vault.azure.net/secrets/PIVNETUAATOKEN?api-version=2016-10-01 -H "Authorization: Bearer ${TOKEN}" | jq -r .value)
pks login -a api.${PKS_SUBDOMAIN_NAME}.${PKS_DOMAIN_NAME} -u k8sadmin -p ${PIVNET_UAA_TOKEN} --skip-ssl-validation
echo "creating cluster ${CLUSTER}, this may take a while"
pks create-cluster ${CLUSTER} \
-e ${CLUSTER}.${PKS_SUBDOMAIN_NAME}.${PKS_DOMAIN_NAME} \
 --plan ${PLAN_NAME} \
 --num-nodes 3 --json --wait
TOKEN=$(curl 'http://169.254.169.254/metadata/identity/oauth2/token?api-version=2018-02-01&resource=https%3A%2F%2Fvault.azure.net' -s -H Metadata:true | jq -r .access_token)
AZURE_SUBSCRIPTION_ID=$(curl -s -H Metadata:true "http://169.254.169.254/metadata/instance/compute?api-version=2017-08-01" | jq -r .subscriptionId)
AZURE_CLIENT_SECRET=$(curl https://${AZURE_VAULT}.vault.azure.net/secrets/AZURECLIENTSECRET?api-version=2016-10-01 -s -H "Authorization: Bearer ${TOKEN}" | jq -r .value)
AZURE_CLIENT_ID=$(curl https://${AZURE_VAULT}.vault.azure.net/secrets/AZURECLIENTID?api-version=2016-10-01 -s -H "Authorization: Bearer ${TOKEN}" | jq -r .value)
AZURE_TENANT_ID=$(curl https://${AZURE_VAULT}.vault.azure.net/secrets/AZURETENANTID?api-version=2016-10-01 -s -H "Authorization: Bearer ${TOKEN}" | jq -r .value)

az login --service-principal \
  --username ${AZURE_CLIENT_ID} \
  --password ${AZURE_CLIENT_SECRET} \
  --tenant ${AZURE_TENANT_ID}

PKS_UUID=$(pks show-cluster ${CLUSTER}  --json | jq -r '.uuid')
pks get-credentials ${CLUSTER} 
MASTER_VM_IDS=$(az vm availability-set show  \
--name p-bosh-service-instance-${PKS_UUID}-master \
--resource-group ${ENV_NAME} \
--output tsv \
--query "virtualMachines[].id" )

MASTER_VM_IDS=$(az vm list \
 --resource-group $ENV_NAME \
 --query "[?tags.job == 'master' && tags.deployment == 'service-instance_${PKS_UUID}'].id" --output tsv)

WORKER_VM_IDS=$(az vm list \
 --resource-group $ENV_NAME \
 --query "[?tags.job == 'worker' && tags.deployment == 'service-instance_${PKS_UUID}'].id" --output tsv )


MASTER_VM_NAME=$(az vm show -d --ids ${MASTER_VM_IDS} \
--query "name" \
--output tsv)

echo "Assigning pks-worker role to Workers"
az vm identity assign \
--identities pks-worker \
--ids ${WORKER_VM_IDS}
echo "Assigning pks-master role to Master(s)"
az vm identity assign \
--identities pks-master \
--ids ${MASTER_VM_IDS}

MASTER_NIC_IDS=$(az vm show -d \
--ids ${MASTER_VM_IDS} \
--query "name || [].name" \
--output tsv | xargs -n1 \
az vm nic list --resource-group $ENV_NAME \
--query "[].id" --output tsv \
--vm-name )


MASTER_NIC_IP_CONFIG=$(az network nic show \
--ids $MASTER_NIC_ID \
--query "ipConfigurations[].id" --out tsv)

az network nic ip-config update --ids ${MASTER_NIC_IP_CONFIG} \
--lb-address-pools ${CLUSTER}-be --lb-name ${CLUSTER}-lb

kubectl apply -f ${TEMPLATE_DIR}/shared_storage.yaml
kubectl apply -f ${TEMPLATE_DIR}/standard_storage.yaml

