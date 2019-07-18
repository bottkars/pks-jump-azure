#!/usr/bin/env bash
source ~/.env.sh
cd ${HOME_DIR}
MYSELF=$(basename $0)
mkdir -p ${LOG_DIR}/
exec &> >(tee -a "${LOG_DIR}/${MYSELF}.$(date '+%Y-%m-%d-%H').log")
exec 2>&1
POSITIONAL=()
while [[ $# -gt 0 ]]
do
key="$1"
case $key in
    -n|--NO_DOWNLOAD)
    NO_DOWNLOAD=TRUE
    echo "No download is ${NO_DOWNLOAD}"
    # shift # past value if  arg value
    ;;
    -d|--DO_NOT_APPLY_CHANGES)
    NO_APPLY=TRUE
    echo "No APPLY is ${NO_APPLY}"
    # shift # past value ia arg value
    ;;
    -lb|--CREATE_LB)
    CREATE_LB=TRUE
    echo "CREATE_LB is ${CREATE_LB}"
    # shift # past value ia arg value
    ;;
    -a|--APPLY_ALL)
    APPLY_ALL=TRUE
    echo "APPLY ALL is ${APPLY_ALL}"
    # shift # past value ia arg value
    ;;              
    *)    # unknown option
    POSITIONAL+=("$1") # save it in an array for later
    shift # past argument
    ;;
esac
shift
done
set -- "${POSITIONAL[@]}" # restore positional parameters
### accept 250er stemcells
RELEASE_JSON=$(curl \
  --header "Authorization: Bearer ${PIVNET_ACCESS_TOKEN}" \
  --fail \
  "https://network.pivotal.io/api/v2/products/233/releases/331971")
# eula acceptance link
EULA_ACCEPTANCE_URL=$(echo ${RELEASE_JSON} |\
  jq -r '._links.eula_acceptance.href')

# eula acceptance
curl \
  --fail \
  --header "Authorization: Bearer ${PIVNET_ACCESS_TOKEN}" \
  --request POST \
  ${EULA_ACCEPTANCE_URL}


${SCRIPT_DIR}/stemcell_loader.sh -s 250

PRODUCT_SLUG="harbor-container-registry"
TOKEN=$(curl 'http://169.254.169.254/metadata/identity/oauth2/token?api-version=2018-02-01&resource=https%3A%2F%2Fvault.azure.net' -s -H Metadata:true | jq -r .access_token)
AZURE_SUBSCRIPTION_ID=$(curl -s -H Metadata:true "http://169.254.169.254/metadata/instance/compute?api-version=2017-08-01" | jq -r .subscriptionId)
AZURE_CLIENT_SECRET=$(curl https://${AZURE_VAULT}.vault.azure.net/secrets/AZURECLIENTSECRET?api-version=2016-10-01 -s -H "Authorization: Bearer ${TOKEN}" | jq -r .value)
AZURE_CLIENT_ID=$(curl https://${AZURE_VAULT}.vault.azure.net/secrets/AZURECLIENTID?api-version=2016-10-01 -s -H "Authorization: Bearer ${TOKEN}" | jq -r .value)
AZURE_TENANT_ID=$(curl https://${AZURE_VAULT}.vault.azure.net/secrets/AZURETENANTID?api-version=2016-10-01 -s -H "Authorization: Bearer ${TOKEN}" | jq -r .value)
PIVNET_UAA_TOKEN=$(curl https://${AZURE_VAULT}.vault.azure.net/secrets/PIVNETUAATOKEN?api-version=2016-10-01 -H "Authorization: Bearer ${TOKEN}" | jq -r .value)

cat << EOF > ${TEMPLATE_DIR}/harbor_vars.yaml
product_name: ${PRODUCT_SLUG}
harbor_hostname: harbor.${PKS_SUBDOMAIN_NAME}.${PKS_DOMAIN_NAME}
harbor_secret: ${PIVNET_UAA_TOKEN}
pks_key_pem: "$(cat ${HOME_DIR}/${PKS_SUBDOMAIN_NAME}.${PKS_DOMAIN_NAME}.key | awk '{printf "%s\\r\\n", $0}')"
pks_cert_pem: "$(cat ${HOME_DIR}/fullchain.cer | awk '{printf "%s\\r\\n", $0}')"
pks_cert_ca: "$(cat ${HOME_DIR}/${PKS_SUBDOMAIN_NAME}.${PKS_DOMAIN_NAME}.ca.crt | awk '{printf "%s\\r\\n", $0}')"
harbor_ip: 10.0.12.10
singleton_zone: ${SINGLETON_ZONE}
zones_map: ${ZONES_MAP}
zones_list: ${ZONES_LIST}
EOF
## copy ca cert for registry login
sudo mkdir -p /etc/docker/certs.d/harbor.${PKS_SUBDOMAIN_NAME}.${PKS_DOMAIN_NAME}
sudo cp ${HOME_DIR}/fullchain.cer /etc/docker/certs.d/harbor.${PKS_SUBDOMAIN_NAME}.${PKS_DOMAIN_NAME}/fullchain.crt
##



if  [ ! -z ${CREATE_LB} ] ; then

az login --service-principal \
  --username ${AZURE_CLIENT_ID} \
  --password ${AZURE_CLIENT_SECRET} \
  --tenant ${AZURE_TENANT_ID}

az network public-ip create \
    --resource-group ${ENV_NAME} \
    --name harbor-public-ip \
    --sku standard \
    --allocation-method static

az network lb create \
    --resource-group ${ENV_NAME} \
    --name harbor-lb \
    --sku standard \
    --tags K8SCLUSTER=harbor \
    --public-ip-address harbor-public-ip \
    --frontend-ip-name harbor-fe \
    --backend-pool-name harbor-be

az network lb probe create \
    --resource-group ${ENV_NAME} \
    --lb-name harbor-lb \
    --name harbor-probe-443 \
    --protocol tcp \
    --port 443

az network lb rule create \
    --resource-group ${ENV_NAME} \
    --lb-name harbor-lb \
    --name rule_443 \
    --protocol tcp \
    --frontend-port 443 \
    --backend-port 443 \
    --frontend-ip-name harbor-fe \
    --backend-pool-name harbor-be \
    --probe-name harbor-probe-443

AZURE_LB_PUBLIC_IP=$(az network public-ip show \
    --resource-group ${ENV_NAME} \
    --name harbor-public-ip \
    --query "{address: ipAddress}" \
    --output tsv)

az network dns record-set a create \
    --resource-group ${ENV_NAME} \
    --zone-name ${PKS_SUBDOMAIN_NAME}.${PKS_DOMAIN_NAME} \
    --name harbor --ttl 60

az network dns record-set a add-record \
    --resource-group ${ENV_NAME} \
    --zone-name ${PKS_SUBDOMAIN_NAME}.${PKS_DOMAIN_NAME} \
    --record-set-name harbor \
    --ipv4-address ${AZURE_LB_PUBLIC_IP}
fi

if  [ ! -z ${NO_APPLY} ] ; then
    ${SCRIPT_DIR}/deploy_tile.sh -t harbor
    elif [ ! -z ${APPLY_ALL} ] ; then
        echo "calling tile Installer with apply All"
        ${SCRIPT_DIR}/deploy_tile.sh -t harbor -a
#    fi
else
    echo "No Product Apply"
    ${SCRIPT_DIR}/deploy_tile.sh -t harbor -d
fi
echo "$(date) end deploy Harbor"