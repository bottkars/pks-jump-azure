cd $1
source .env.sh
MYSELF=$(basename $0)
mkdir -p ${HOME_DIR}/logs
exec &> >(tee -a "${HOME_DIR}/logs/${MYSELF}.$(date '+%Y-%m-%d-%H').log")
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
source ~/.env.sh
START_OPSMAN_DEPLOY_TIME=$(date)
echo ${START_OPSMAN_DEPLOY_TIME} start opsman deployment
$(cat <<-EOF >> ${HOME_DIR}/.env.sh
START_OPSMAN_DEPLOY_TIME="${START_OPSMAN_DEPLOY_TIME}"
EOF
)

pushd ${HOME_DIR}

cd ./pivotal-cf-terraforming-azure-*/
cd terraforming-pks
NET_16_BIT_MASK="10.0" #this is static in terraform 0.29
AZURE_NAMESERVERS=$(terraform output env_dns_zone_name_servers)
SSH_PRIVATE_KEY="$(terraform output -json ops_manager_ssh_private_key | jq .value)"
SSH_PUBLIC_KEY="$(terraform output ops_manager_ssh_public_key)"
BOSH_DEPLOYED_VMS_SECURITY_GROUP_NAME="$(terraform output bosh_deployed_vms_security_group_name)"
PKS_OPSMAN_FQDN="$(terraform output ops_manager_dns)"
INFRASTRUCTURE_SUBNET_CIDRS="$(terraform output infrastructure_subnet_cidrs)"
SERVICES_SUBNET_CIDRS="$(terraform output services_subnet_cidrs)"
PKS_SUBNET_CIDRS="$(terraform output pks_subnet_cidrs)"
SERVICES_SUBNET_GATEWAY="$(terraform output services_subnet_gateway)"
PKS_SUBNET_GATEWAY="$(terraform output pks_subnet_gateway)"
INFRASTRUCTURE_SUBNET_GATEWAY="$(terraform output infrastructure_subnet_gateway)"
echo "checking opsman api ready using the new fqdn ${PKS_OPSMAN_FQDN},
if the . keeps showing, check if ns record for ${PKS_SUBDOMAIN_NAME}.${PKS_DOMAIN_NAME} has
${AZURE_NAMESERVERS}
as server entries"
until $(curl --output /dev/null --silent --head --fail -k -X GET "https://${PKS_OPSMAN_FQDN}/api/v0/info"); do
    printf '.'
    sleep 5
done
echo "done"

export OM_TARGET=${PKS_OPSMAN_FQDN}
export OM_USERNAME=${PKS_OPSMAN_USERNAME}
export OM_PASSWORD="${PIVNET_UAA_TOKEN}"

om --skip-ssl-validation \
configure-authentication \
--decryption-passphrase ${PIVNET_UAA_TOKEN}

echo checking deployed products
om --skip-ssl-validation \
deployed-products


cd ${HOME_DIR}
cat << EOF > director_vars.yaml
subscription_id: ${AZURE_SUBSCRIPTION_ID}
tenant_id: ${AZURE_TENANT_ID}
client_id: ${AZURE_CLIENT_ID}
client_secret: ${AZURE_CLIENT_SECRET}
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


EOF

#infrastructure_cidr: "${INFRASTRUCTURE_CIDR}"

#pks_gateway: "${NET_16_BIT_MASK}.0.1"
#services_cidr: "${SERVICES_CIDR}"

om --skip-ssl-validation \
 configure-director --config ${HOME_DIR}/director_config.yaml --vars-file ${HOME_DIR}/director_vars.yaml

retryop "om --skip-ssl-validation apply-changes" 2 10


echo checking deployed products
om --skip-ssl-validation \
 deployed-products

popd
END_OPSMAN_DEPLOY_TIME=$(date)
echo ${END_OPSMAN_DEPLOY_TIME} finished opsman deployment
$(cat <<-EOF >> ${HOME_DIR}/.env.sh
PKS_OPSMAN_FQDN="${PKS_OPSMAN_FQDN}"
END_OPSMAN_DEPLOY_TIME="${END_OPSMAN_DEPLOY_TIME}"
EOF
)
echo Started BASE deployment at ${START_BASE_DEPLOY_TIME}
echo Fimnished BASE deployment at ${END_BASE_DEPLOY_TIME}
echo Started OPSMAN deployment at ${START_OPSMAN_DEPLOY_TIME}
echo Finished OPSMAN Deployment at ${END_OPSMAN_DEPLOY_TIME}

if [ "${PKS_AUTOPILOT}" = "TRUE" ]; then
    if [ "${USE_SELF_CERTS}" = "TRUE" ]; then
      sudo -S -u ${ADMIN_USERNAME} ${HOME_DIR}/create_self_certs.sh
    else  
      sudo -S -u ${ADMIN_USERNAME} ${HOME_DIR}/create_certs.sh
    fi
    sudo -S -u ${ADMIN_USERNAME} ${HOME_DIR}/deploy_pks.sh
fi
