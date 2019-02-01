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
    -n|--NO_DOWNLOAD)
    NO_DOWNLOAD=TRUE
    shift # past argument
    #shift # past value
    ;;
    *)    # unknown option
    POSITIONAL+=("$1") # save it in an array for later
    shift # past argument
    ;;
esac
done
set -- "${POSITIONAL[@]}" # restore positional parameters
source ~/.env.sh
export OM_TARGET=${PKS_OPSMAN_FQDN}
export OM_USERNAME=${PKS_OPSMAN_USERNAME}
export OM_PASSWORD="${PIVNET_UAA_TOKEN}"

declare -a FILES=("${HOME_DIR}/${PKS_SUBDOMAIN_NAME}.${PKS_DOMAIN_NAME}.key" \
"${HOME_DIR}/fullchain.cer")
for FILE in "${FILES[@]}"; do
    if [ ! -f $FILE ]; then
    echo "$FILE not found. Please run create_self_certs.sh "
    exit
    fi
done



START_PKS_DEPLOY_TIME=$(date)
$(cat <<-EOF >> ${HOME_DIR}/.env.sh
START_PKS_DEPLOY_TIME="${START_PKS_DEPLOY_TIME}"
EOF
)
source ${HOME_DIR}/pks.env

PKS_OPSMAN_ADMIN_PASSWD=${PIVNET_UAA_TOKEN}
PKS_KEY_PEM=$(cat ${HOME_DIR}/${PKS_SUBDOMAIN_NAME}.${PKS_DOMAIN_NAME}.key | awk '{printf "%s\\r\\n", $0}')
PKS_CERT_PEM=$(cat ${HOME_DIR}/fullchain.cer | awk '{printf "%s\\r\\n", $0}')
PKS_CREDHUB_KEY="01234567890123456789"
PKS_API_HOSTNAME="api.${PKS_SUBDOMAIN_NAME}.${PKS_DOMAIN_NAME}"
PKS_LB="${ENV_NAME}-pks-lb"
cd ${HOME_DIR}
#Authenticate pivnet 
DOWNLOAD_DIR_FULL=${DOWNLOAD_DIR}/${PRODUCT_SLUG}/${PKS_VERSION}
mkdir  -p ${DOWNLOAD_DIR_FULL}

PIVNET_ACCESS_TOKEN=$(curl \
  --fail \
  --header "Content-Type: application/json" \
  --data "{\"refresh_token\": \"${PIVNET_UAA_TOKEN}\"}" \
  https://network.pivotal.io/api/v2/authentication/access_tokens |\
    jq -r '.access_token')

# release by slug
RELEASE_JSON=$(curl \
  --header "Authorization: Bearer ${PIVNET_ACCESS_TOKEN}" \
  --fail \
  "https://network.pivotal.io/api/v2/products/${PRODUCT_SLUG}/releases/${RELEASE_ID}")
# eula acceptance link
EULA_ACCEPTANCE_URL=$(echo ${RELEASE_JSON} |\
  jq -r '._links.eula_acceptance.href')


# eula acceptance
curl \
  --fail \
  --header "Authorization: Bearer ${PIVNET_ACCESS_TOKEN}" \
  --request POST \
  ${EULA_ACCEPTANCE_URL}



# download product using om cli
if  [ -z ${NO_DOWNLOAD} ] ; then


echo $(date) start downloading PKS
om --skip-ssl-validation \
  download-product \
 --pivnet-api-token ${PIVNET_UAA_TOKEN} \
 --pivnet-file-glob "*.pivotal" \
 --pivnet-product-slug ${PRODUCT_SLUG} \
 --product-version ${PKS_VERSION} \
 --stemcell-iaas azure \
 --download-stemcell \
 --output-directory ${DOWNLOAD_DIR_FULL}


echo $(date) start downloading PKS CLI
om --skip-ssl-validation \
  download-product \
 --pivnet-api-token ${PIVNET_UAA_TOKEN} \
 --pivnet-file-glob "pks-linux-amd64*" \
 --pivnet-product-slug ${PRODUCT_SLUG} \
 --product-version ${PKS_VERSION} \
 --output-directory ${HOME_DIR}


echo $(date) end downloading PKS CLI
chmod +x ./pks-linux-amd*
chown ${ADMIN_USERNAME}.${ADMIN_USERNAME} ./pks-linux-amd*
sudo cp ./pks-linux-amd* /usr/local/bin/pks


echo $(date) start downloading kubectl
om --skip-ssl-validation \
  download-product \
 --pivnet-api-token ${PIVNET_UAA_TOKEN} \
 --pivnet-file-glob "kubectl-linux-amd64*" \
 --pivnet-product-slug ${PRODUCT_SLUG} \
 --product-version ${PKS_VERSION} \
 --output-directory ${HOME_DIR}


echo $(date) end downloading kubectl


chmod +x ./kubectl-linux-amd64*
chown ${ADMIN_USERNAME}.${ADMIN_USERNAME} ./kubectl-linux-amd64*
sudo cp ./kubectl-linux-amd64* /usr/local/bin/kubectl


echo $(date) start downloading helm
curl https://raw.githubusercontent.com/helm/helm/master/scripts/get > get_helm.sh
chmod 700 get_helm.sh
./get_helm.sh
echo $(date) end downloading helm



echo $(date) end downloading PKS and componenets
else 
echo ignoring download by user 
fi

TARGET_FILENAME=$(cat ${DOWNLOAD_DIR_FULL}/download-file.json | jq -r '.product_path')
STEMCELL_FILENAME=$(cat ${DOWNLOAD_DIR_FULL}/download-file.json | jq -r '.stemcell_path')

# Import the tile to Ops Manager.
echo $(date) start uploading PKS
om --skip-ssl-validation \
  --request-timeout 3600 \
  upload-product \
  --product ${TARGET_FILENAME}

echo $(date) end uploading PKS

    # 1. Find the version of the product that was imported.
PRODUCTS=$(om --skip-ssl-validation \
  available-products \
    --format json)

VERSION=$(echo ${PRODUCTS} |\
  jq --arg product_name ${PRODUCT_SLUG} -r 'map(select(.name==$product_name)) | first | .version')

# 2.  Stage using om cli
echo $(date) start staging PKS 
om --skip-ssl-validation \
  stage-product \
  --product-name ${PRODUCT_SLUG} \
  --product-version ${VERSION}
echo $(date) end staging PKS 

cat << EOF > vars.yaml
network: ${ENV_NAME}-pks-subnet
services_network: ${ENV_NAME}-pks-services-subnet
subscription_id: ${AZURE_SUBSCRIPTION_ID}
tenant_id: ${AZURE_TENANT_ID}
resource_group_name: ${ENV_NAME}
azure_location: ${LOCATION}
pks_web_lb: ${PKS_WEB_LB}
vnet_name: ${ENV_NAME}-virtual-network
default_security_group: ${ENV_NAME}-pks-api-sg
pks_cert_pem: "${PKS_CERT_PEM}"
pks_key_pem: "${PKS_KEY_PEM}"
pks_api_hostname: "${PKS_API_HOSTNAME}"
pks_lb: "${PKS_LB}"
primary_availability_set: "${ENV_NAME}-availability-set"
EOF

#
#pks_system_domain: ${PKS_SYSTEM_DOMAIN}
#pks_apps_domain: ${PKS_APPS_DOMAIN}
#pks_notifications_email: ${PKS_NOTIFICATIONS_EMAIL}
#pks_cert_pem: "${PKS_CERT_PEM}"
#pks_key_pem: "${PKS_KEY_PEM}"
#pks_credhub_key: "${PKS_CREDHUB_KEY}"
#pks_diego_ssh_lb: ${PKS_DIEGO_SSH_LB}
#pks_mysql_lb: ${PKS_MYSQL_LB}
#>
om --skip-ssl-validation \
  upload-stemcell \
  --stemcell ${STEMCELL_FILENAME}

om --skip-ssl-validation \
  configure-product \
  -c pks.yaml -l vars.yaml
###


  
echo $(date) start apply PKS
om --skip-ssl-validation \
  apply-changes
echo $(date) end apply PKS

END_PKS_DEPLOY_TIME=$(date)
$(cat <<-EOF >> ${HOME_DIR}/.env.sh
END_PKS_DEPLOY_TIME="${END_PKS_DEPLOY_TIME}"
EOF
)
./create_user.sh
./create_lb.sh --K8S_CLUSTER_NAME k8s1
./create_cluster.sh --K8S_CLUSTER_NAME k8s1
./deploy_docker.sh

echo Finished
echo Started BASE deployment at ${START_BASE_DEPLOY_TIME}
echo Fimnished BASE deployment at ${END_BASE_DEPLOY_TIME}
echo Started OPSMAN deployment at ${START_OPSMAN_DEPLOY_TIME}
echo Finished OPSMAN Deployment at ${END_OPSMAN_DEPLOY_TIME}
echo Started PKS deployment at ${START_PKS_DEPLOY_TIME}
echo Finished PKS Deployment at ${END_PKS_DEPLOY_TIME}