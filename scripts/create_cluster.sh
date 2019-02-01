#!/usr/bin/env bash
source .env.sh
MYSELF=$(basename $0)
mkdir -p ${HOME_DIR}/logs
exec &> >(tee -a "${HOME_DIR}/logs/${MYSELF}.$(date '+%Y-%m-%d-%H').log")
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
source ~/.env.sh
pks login -a api.${PKS_SUBDOMAIN_NAME}.${PKS_DOMAIN_NAME} -u k8sadmin -p ${PIVNET_UAA_TOKEN} --skip-ssl-validation
echo "creating cluster ${CLUSTER}, this may take a while"
pks create-cluster ${CLUSTER} \
-e ${CLUSTER}.${PKS_SUBDOMAIN_NAME}.${PKS_DOMAIN_NAME} \
 --plan small \
 --num-nodes 3 --json --wait

az login --service-principal \
  --username ${AZURE_CLIENT_ID} \
  --password ${AZURE_CLIENT_SECRET} \
  --tenant ${AZURE_TENANT_ID}

PKS_UUID=$(pks show-cluster ${CLUSTER}  --json | jq -r '.uuid')
pks create-cluster ${CLUSTER}
MASTER_VM_ID=$(az vm availability-set show  \
--name p-bosh-service-instance-${PKS_UUID}-master \
--resource-group ${ENV_NAME} \
--output tsv \
--query "virtualMachines[].id" )

MASTER_VM_NAME=$(az vm show -d --ids ${MASTER_VM_ID} \
--query "name" \
--output tsv)

MASTER_NIC_ID=$(az vm nic list \
--vm-name ${MASTER_VM_NAME} \
--resource-group $ENV_NAME \
--query "[].id" --output tsv)

MASTER_NIC_IP_CONFIG=$(az network nic show \
--ids $MASTER_NIC_ID \
--query "ipConfigurations[].id" --out tsv)


az network nic ip-config update --ids ${MASTER_NIC_IP_CONFIG} \
--lb-address-pools ${CLUSTER}-be --lb-name ${CLUSTER}-lb

