#!/usr/bin/env bash
POSITIONAL=()
while [[ $# -gt 0 ]]
do
key="$1"

case $key in
    -h|--HOME)
    HOME_DIR="$2"
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

if  [ -z ${HOME_DIR} ] ; then
 echo "Please specify HOME DIR -h|--HOME"
 exit 1
fi 

cd ${HOME_DIR}
source ${HOME_DIR}/.env.sh
MYSELF=$(basename $0)
mkdir -p ${LOG_DIR}
exec &> >(tee -a "${LOG_DIR}/${MYSELF}.$(date '+%Y-%m-%d-%H').log")
exec 2>&1
function retryop()
{
  retry=0
  max_retries=$2
  interval=$3
  while [ ${retry} -lt ${max_retries} ]; do
    echo "Operation: $1, Retry #${retry}"
    eval $1
    if [ $? -eq 0 ]; then
      echo "Successful"
      break
    else
      let retry=retry+1
      echo "Sleep $interval seconds, then retry..."
      sleep $interval
    fi
  done
  if [ ${retry} -eq ${max_retries} ]; then
    echo "Operation failed: $1"
    exit 1
  fi
}
###
pushd ${HOME_DIR}

#  FAKING TERRAFORM DOWNLOAD FOR PKS
PRODUCT_SLUG="elastic-runtime"
RELEASE_ID="259105"

### updating om
OM_VER=2.0.1
wget -O om https://github.com/pivotal-cf/om/releases/download/${OM_VER}/om-linux-${OM_VER} && \
  chmod +x om && \
  sudo mv om /usr/local/bin/
###  

###  setting secret env from vault 


TOKEN=$(curl 'http://169.254.169.254/metadata/identity/oauth2/token?api-version=2018-02-01&resource=https%3A%2F%2Fvault.azure.net' -s -H Metadata:true | jq -r .access_token)

export TF_VAR_subscription_id=$(curl -s -H Metadata:true "http://169.254.169.254/metadata/instance/compute?api-version=2017-08-01" | jq -r .subscriptionId)
export TF_VAR_client_secret=$(curl https://${AZURE_VAULT}.vault.azure.net/secrets/AZURECLIENTSECRET?api-version=2016-10-01 -s -H "Authorization: Bearer ${TOKEN}" | jq -r .value)
export TF_VAR_client_id=$(curl https://${AZURE_VAULT}.vault.azure.net/secrets/AZURECLIENTID?api-version=2016-10-01 -s -H "Authorization: Bearer ${TOKEN}" | jq -r .value)
export TF_VAR_tenant_id=$(curl https://${AZURE_VAULT}.vault.azure.net/secrets/AZURETENANTID?api-version=2016-10-01 -s -H "Authorization: Bearer ${TOKEN}" | jq -r .value)
PIVNET_UAA_TOKEN=$(curl https://${AZURE_VAULT}.vault.azure.net/secrets/PIVNETUAATOKEN?api-version=2016-10-01 -H "Authorization: Bearer ${TOKEN}" | jq -r .value)

###

AUTHENTICATION_RESPONSE=$(curl \
  --fail \
  --data "{\"refresh_token\": \"${PIVNET_UAA_TOKEN}\"}" \
  https://network.pivotal.io/api/v2/authentication/access_tokens)

PIVNET_ACCESS_TOKEN=$(echo ${AUTHENTICATION_RESPONSE} | jq -r '.access_token')
# Get the release JSON for the PKS version you want to install:

RELEASE_JSON=$(curl \
    --fail \
    "https://network.pivotal.io/api/v2/products/${PRODUCT_SLUG}/releases/${RELEASE_ID}")

# ACCEPTING EULA

EULA_ACCEPTANCE_URL=$(echo ${RELEASE_JSON} |\
  jq -r '._links.eula_acceptance.href')

curl \
  --fail \
  --header "Authorization: Bearer ${PIVNET_ACCESS_TOKEN}" \
  --request POST \
  ${EULA_ACCEPTANCE_URL}

# GET TERRAFORM FOR PKS AZURE


DOWNLOAD_ELEMENT=$(echo ${RELEASE_JSON} |\
  jq -r '.product_files[] | select(.aws_object_key | contains("terraforming-azure"))')

FILENAME=$(echo ${DOWNLOAD_ELEMENT} |\
  jq -r '.aws_object_key | split("/") | last')

URL=$(echo ${DOWNLOAD_ELEMENT} |\
  jq -r '._links.download.href')

# download terraform

curl \
  --fail \
  --location \
  --output ${FILENAME} \
  --header "Authorization: Bearer ${PIVNET_ACCESS_TOKEN}" \
  ${URL}
sudo -S -u ${ADMIN_USERNAME} unzip ${FILENAME}
cd ${HOME_DIR}/pivotal-cf-terraforming-azure-*/terraforming-pks
NET_16_BIT_MASK="10.0" # static for now due to bug
 # preparation work for terraform
cat << EOF > terraform.tfvars
env_name              = "${ENV_NAME}"
env_short_name        = "${ENV_SHORT_NAME}"
ops_manager_image_uri = "${OPS_MANAGER_IMAGE_URI}"
location              = "${LOCATION}"
dns_suffix            = "${PKS_DOMAIN_NAME}"
dns_subdomain         = "${PKS_SUBDOMAIN_NAME}"
ops_manager_private_ip = "${NET_16_BIT_MASK}.8.4"
# pcf_infrastructure_subnet = "${NET_16_BIT_MASK}.8.0/26"
# pks_subnet_cidrs = "${NET_16_BIT_MASK}.0.0/22"
# services_subnet_cidrs = "${NET_16_BIT_MASK}.4.0/22"
pcf_virtual_network_address_space = ["${NET_16_BIT_MASK}.0.0/16"]
EOF
# patch terraform for managed identity if tf is 0.29


chmod 755 terraform.tfvars
chown ${ADMIN_USERNAME}.${ADMIN_USERNAME} terraform.tfvars

cd ./pivotal-cf-terraforming-azure-*/terraforming-pks

PATCH_SERVER="https://raw.githubusercontent.com/bottkars/pks-jump-azure/master/patches/"
wget -q ${PATCH_SERVER}main.tf -O ./main.tf
wget -q ${PATCH_SERVER}variables.tf -O ./variables.tf
wget -q ${PATCH_SERVER}modules/pks/networking.tf -O ../modules/pks/networking.tf
wget -q ${PATCH_SERVER}modules/pks/variables.tf -O ../modules/pks/variables.tf
# end patch 
TOKEN=$(curl 'http://169.254.169.254/metadata/identity/oauth2/token?api-version=2018-02-01&resource=https%3A%2F%2Fvault.azure.net' -s -H Metadata:true | jq -r .access_token)
AZURE_SUBSCRIPTION_ID=$(curl -s -H Metadata:true "http://169.254.169.254/metadata/instance/compute?api-version=2017-08-01" | jq -r .subscriptionId)
AZURE_CLIENT_SECRET=$(curl https://${AZURE_VAULT}.vault.azure.net/secrets/AZURECLIENTSECRET?api-version=2016-10-01 -s -H "Authorization: Bearer ${TOKEN}" | jq -r .value)
AZURE_CLIENT_ID=$(curl https://${AZURE_VAULT}.vault.azure.net/secrets/AZURECLIENTID?api-version=2016-10-01 -s -H "Authorization: Bearer ${TOKEN}" | jq -r .value)
AZURE_TENANT_ID=$(curl https://${AZURE_VAULT}.vault.azure.net/secrets/AZURETENANTID?api-version=2016-10-01 -s -H "Authorization: Bearer ${TOKEN}" | jq -r .value)
az login --service-principal \
  --username ${AZURE_CLIENT_ID} \
  --password ${AZURE_CLIENT_SECRET} \
  --tenant ${AZURE_TENANT_ID}
 
az role definition delete \
  --name ${TF_VAR_subscription_id}-${ENV_NAME}-pks-worker-role
az role definition delete \
  --name ${TF_VAR_subscription_id}-${ENV_NAME}-pks-master-role

terraform init

retryop "terraform apply -auto-approve" 3 10

terraform output ops_manager_ssh_private_key > ${HOME_DIR}/opsman
chmod 600 ${HOME_DIR}/opsman

 
AZURE_LB_PUBLIC_IP=$(az network public-ip show \
  --resource-group ${ENV_NAME} \
  --name ${ENV_NAME}-pks-lb-ip \
  --query "{address: ipAddress}" \
  --output tsv)

az network dns record-set a create \
--resource-group ${ENV_NAME} \
--zone-name ${PKS_SUBDOMAIN_NAME}.${PKS_DOMAIN_NAME} \
--name api --ttl 60 


az network dns record-set a add-record \
--resource-group ${ENV_NAME} \
--zone-name ${PKS_SUBDOMAIN_NAME}.${PKS_DOMAIN_NAME} \
--record-set-name api \
--ipv4-address ${AZURE_LB_PUBLIC_IP}

az network nsg rule create \
--nsg-name ${ENV_NAME}-bosh-deployed-vms-security-group \
--resource-group ${ENV_NAME} \
--name Port_8443 \
--priority 220 \
--source-address-prefixes '*' \
--source-port-ranges '*' \
--destination-address-prefixes '*' \
--destination-port-ranges 8443 \
--access allow \
--protocol Tcp \
--description "Allow UAA and K8S Access"

az network nsg rule create \
--nsg-name ${ENV_NAME}-bosh-deployed-vms-security-group \
--resource-group ${ENV_NAME} \
--name Port_9021 \
--priority 230 \
--source-address-prefixes '*' \
--source-port-ranges '*' \
--destination-address-prefixes '*' \
--destination-port-ranges 9021 \
--access allow \
--protocol Tcp \
--description "Allow UAA and K8S Access"

# network peerings for bosh
echo creating network peerings

VNet1Id=$(az network vnet show \
  --resource-group ${JUMP_RG} \
  --name ${JUMP_VNET} \
  --query id --out tsv)

VNet2Id=$(az network vnet show \
  --resource-group ${ENV_NAME} \
  --name ${ENV_NAME}-virtual-network \
  --query id --out tsv)

az network vnet peering create --name PKS-Peer \
--remote-vnet-id ${VNet2Id} \
--resource-group ${JUMP_RG} \
--vnet-name ${JUMP_VNET} \
--allow-forwarded-traffic \
--allow-gateway-transit \
--allow-vnet-access

az network vnet peering create --name JUMP-Peer \
--remote-vnet-id ${VNet1Id} \
--resource-group ${ENV_NAME} \
--vnet-name ${ENV_NAME}-virtual-network \
--allow-forwarded-traffic \
--allow-gateway-transit \
--allow-vnet-access




###
START_OPSMAN_DEPLOY_TIME=$(date)
echo ${START_OPSMAN_DEPLOY_TIME} start opsman deployment




NET_16_BIT_MASK="10.0" #this is static in terraform 0.29
AZURE_NAMESERVERS=$(terraform output env_dns_zone_name_servers)
SSH_PRIVATE_KEY="$(terraform output -json ops_manager_ssh_private_key | jq .value)"
SSH_PUBLIC_KEY="$(terraform output ops_manager_ssh_public_key)"
BOSH_DEPLOYED_VMS_SECURITY_GROUP_NAME="$(terraform output bosh_deployed_vms_security_group_name)"
PCF_OPSMAN_FQDN="$(terraform output ops_manager_dns)"
INFRASTRUCTURE_SUBNET_CIDRS="$(terraform output infrastructure_subnet_cidrs)"
SERVICES_SUBNET_CIDRS="$(terraform output services_subnet_cidrs)"
PKS_SUBNET_CIDRS="$(terraform output pks_subnet_cidrs)"
SERVICES_SUBNET_GATEWAY="$(terraform output services_subnet_gateway)"
PKS_SUBNET_GATEWAY="$(terraform output pks_subnet_gateway)"
INFRASTRUCTURE_SUBNET_GATEWAY="$(terraform output infrastructure_subnet_gateway)"
echo "checking opsman api ready using the new fqdn ${PCF_OPSMAN_FQDN},
if the . keeps showing, check if ns record for ${PKS_SUBDOMAIN_NAME}.${PKS_DOMAIN_NAME} has
${AZURE_NAMESERVERS}
as server entries"
until $(curl --output /dev/null --silent --head --fail -k -X GET "https://${PCF_OPSMAN_FQDN}/api/v0/info"); do
    printf '.'
    sleep 5
done
echo "done"

OM_ENV_FILE="${HOME_DIR}/om_${ENV_NAME}.env"
cat << EOF > ${OM_ENV_FILE}
---
target: ${PCF_OPSMAN_FQDN}
connect-timeout: 30          # default 5
request-timeout: 3600        # default 1800
skip-ssl-validation: true   # default false
username: ${PCF_OPSMAN_USERNAME}
password: ${PIVNET_UAA_TOKEN}
decryption-passphrase: ${PIVNET_UAA_TOKEN}
EOF


om --env "${HOME_DIR}/om_${ENV_NAME}.env"  \
configure-authentication \
--decryption-passphrase ${PIVNET_UAA_TOKEN}  \
--username ${PCF_OPSMAN_USERNAME} \
--password ${PIVNET_UAA_TOKEN}

echo checking deployed products
om --env "${HOME_DIR}/om_${ENV_NAME}.env"  \
deployed-products


echo checking deployed products
om --env "${HOME_DIR}/om_${ENV_NAME}.env"  \
deployed-products
declare -a FILES=("${HOME_DIR}/${PKS_SUBDOMAIN_NAME}.${PKS_DOMAIN_NAME}.key" \
"${HOME_DIR}/fullchain.cer")
# are we first time ?!

for FILE in "${FILES[@]}"; do
    if [ ! -f $FILE ]; then
      if [ "${USE_SELF_CERTS}" = "TRUE" ]; then
        sudo -S -u ${ADMIN_USERNAME} ${SCRIPT_DIR}/create_self_certs.sh
      else  
        sudo -S -u ${ADMIN_USERNAME} ${SCRIPT_DIR}/create_certs.sh
      fi
    fi  
done
## did let´sencrypt just not work ?
for FILE in "${FILES[@]}"; do
    if [ ! -f $FILE ]; then
    echo "$FILE not found. running Create Self Certs "
    ${SCRIPT_DIR}/create_self_certs.sh
    fi
done


om --env "${HOME_DIR}/om_${ENV_NAME}.env"  \
update-ssl-certificate \
    --certificate-pem "$(cat ${HOME_DIR}/fullchain.cer)" \
    --private-key-pem "$(cat ${HOME_DIR}/${PKS_SUBDOMAIN_NAME}.${PKS_DOMAIN_NAME}.key)"


cd ${HOME_DIR}
cat << EOF > ${TEMPLATE_DIR}/director_vars.yaml
subscription_id: ${TF_VAR_subscription_id}
tenant_id: ${TF_VAR_tenant_id}
client_id: ${TF_VAR_client_id}
client_secret: ${TF_VAR_client_secret}
resource_group_name: ${ENV_NAME}
bosh_storage_account_name: ${ENV_SHORT_NAME}director
default_security_group: ${BOSH_DEPLOYED_VMS_SECURITY_GROUP_NAME}
ssh_public_key: ${SSH_PUBLIC_KEY}
ssh_private_key: ${SSH_PRIVATE_KEY}
ntp_servers_string: 'time.windows.com'
infrastructure-subnet: "${ENV_NAME}-virtual-network/${ENV_NAME}-infrastructure-subnet"
pks-subnet: "${ENV_NAME}-virtual-network/${ENV_NAME}-pks-subnet"
services-subnet: "${ENV_NAME}-virtual-network/${ENV_NAME}-pks-services-subnet"
services_subnet_cidrs: "${SERVICES_SUBNET_CIDRS}"
infrastructure_subnet_cidrs: "${INFRASTRUCTURE_SUBNET_CIDRS}"
infrastructure_subnet_range: "${NET_16_BIT_MASK}.8.1-${NET_16_BIT_MASK}.8.10"
infrastructure_subnet_gateway: "${INFRASTRUCTURE_SUBNET_GATEWAY}"
services_subnet_range: "${NET_16_BIT_MASK}.16.1-${NET_16_BIT_MASK}.16.4"
services_subnet_gateway: "$SERVICES_SUBNET_GATEWAY"
pks_subnet_cidrs: "${PKS_SUBNET_CIDRS}"
pks_subnet_gateway: "${PKS_SUBNET_GATEWAY}"
pks_subnet_range: "${NET_16_BIT_MASK}.12.1-${NET_16_BIT_MASK}.12.4"
fullchain: "$(cat ${HOME_DIR}/fullchain.cer | awk '{printf "%s\\r\\n", $0}')"
EOF

#infrastructure_cidr: "${INFRASTRUCTURE_CIDR}"

#pks_gateway: "${NET_16_BIT_MASK}.0.1"
#services_cidr: "${SERVICES_CIDR}"

om --env "${HOME_DIR}/om_${ENV_NAME}.env"  \
 configure-director --config ${TEMPLATE_DIR}/director_config.yaml --vars-file ${TEMPLATE_DIR}/director_vars.yaml

retryop "om --env "${HOME_DIR}/om_${ENV_NAME}.env"  apply-changes" 2 10


echo checking deployed products
om --env "${HOME_DIR}/om_${ENV_NAME}.env"  \
 deployed-products

popd
END_OPSMAN_DEPLOY_TIME=$(date)
$(cat <<-EOF >> ${HOME_DIR}/.env.sh
PCF_OPSMAN_FQDN="${PCF_OPSMAN_FQDN}"
EOF
)
echo "opsman deployment finished at $(date)"
if [ "${PKS_AUTOPILOT}" = "TRUE" ]; then
    echo "Now calling PKS deployment"
    sudo -S -u ${ADMIN_USERNAME} ${SCRIPT_DIR}/deploy_pks.sh
fi
echo "Finished deployment !!!
if you tailed the installation log, it is time to 'ctrl-c' "
