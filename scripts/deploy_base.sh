#!/usr/bin/env bash
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

START_BASE_DEPLOY_TIME=$(date)
echo ${START_BASE_DEPLOY_TIME} starting base deployment
echo "Installing jq"
retryop "apt-get update && apt-get install -y jq" 10 30

function get_setting() {
  key=$1
  local value=$(echo $settings | jq ".$key" -r)
  echo $value
}

custom_data_file="/var/lib/cloud/instance/user-data.txt"
settings=$(cat ${custom_data_file})
ADMIN_USERNAME=$(get_setting ADMIN_USERNAME)
AZURE_CLIENT_ID=$(get_setting AZURE_CLIENT_ID)
AZURE_CLIENT_SECRET=$(get_setting AZURE_CLIENT_SECRET)
AZURE_SUBSCRIPTION_ID=$(get_setting AZURE_SUBSCRIPTION_ID)
AZURE_TENANT_ID=$(get_setting AZURE_TENANT_ID)
PIVNET_UAA_TOKEN=$(get_setting PIVNET_UAA_TOKEN)
ENV_NAME=$(get_setting ENV_NAME)
ENV_SHORT_NAME=$(get_setting ENV_SHORT_NAME)
OPS_MANAGER_IMAGE_URI=$(get_setting OPS_MANAGER_IMAGE_URI)
LOCATION=$(get_setting LOCATION)
PKS_DOMAIN_NAME=$(get_setting PKS_DOMAIN_NAME)
PKS_SUBDOMAIN_NAME=$(get_setting PKS_SUBDOMAIN_NAME)
PRODUCT_SLUG=$(get_setting PRODUCT_SLUG)
RELEASE_ID=$(get_setting RELEASE_ID)
PKS_OPSMAN_USERNAME=$(get_setting PKS_OPSMAN_USERNAME)
PKS_NOTIFICATIONS_EMAIL=$(get_setting PKS_NOTIFICATIONS_EMAIL)
PKS_AUTOPILOT=$(get_setting PKS_AUTOPILOT)
PKS_PKS_VERSION=$(get_setting PKS_PKS_VERSION)
NET_16_BIT_MASK=$(get_setting NET_16_BIT_MASK)


HOME_DIR="/home/${ADMIN_USERNAME}"
chown ${ADMIN_USERNAME}.${ADMIN_USERNAME} /mnt
chmod 755 /mnt
cp *.sh ${HOME_DIR}
chown ${ADMIN_USERNAME}.${ADMIN_USERNAME} ${HOME_DIR}/*.sh
chmod 755 ${HOME_DIR}/*.sh
chmod +X ${HOME_DIR}/*.sh
cp *.yaml ${HOME_DIR}
chown ${ADMIN_USERNAME}.${ADMIN_USERNAME} ${HOME_DIR}/*.yaml
chmod 755 ${HOME_DIR}/*.yaml

$(cat <<-EOF > ${HOME_DIR}/.env.sh
#!/usr/bin/env bash
ADMIN_USERNAME="${ADMIN_USERNAME}"
AZURE_CLIENT_SECRET="${AZURE_CLIENT_SECRET}"
AZURE_CLIENT_ID="${AZURE_CLIENT_ID}"
AZURE_TENANT_ID="${AZURE_TENANT_ID}"
AZURE_SUBSCRIPTION_ID="${AZURE_SUBSCRIPTION_ID}"
PIVNET_UAA_TOKEN="${PIVNET_UAA_TOKEN}"
ENV_NAME="${ENV_NAME}"
ENV_SHORT_NAME="${ENV_SHORT_NAME}"
OPS_MANAGER_IMAGE_URI="${OPS_MANAGER_IMAGE_URI}"
LOCATION="${LOCATION}"
PKS_DOMAIN_NAME="${PKS_DOMAIN_NAME}"
PKS_SUBDOMAIN_NAME="${PKS_SUBDOMAIN_NAME}"
PRODUCT_SLUG="${PRODUCT_SLUG}"
RELEASE_ID="${RELEASE_ID}"
HOME_DIR="${HOME_DIR}"
PKS_OPSMAN_USERNAME="${PKS_OPSMAN_USERNAME}"
PKS_NOTIFICATIONS_EMAIL="${PKS_NOTIFICATIONS_EMAIL}"
PKS_AUTOPILOT="${PKS_AUTOPILOT}"
PKS_PKS_VERSION="${PKS_PKS_VERSION}"
NET_16_BIT_MASK="${NET_16_BIT_MASK}"
START_BASE_DEPLOY_TIME="${START_BASE_DEPLOY_TIME}"
EOF
)

chmod 600 ${HOME_DIR}/.env.sh
chown ${ADMIN_USERNAME}.${ADMIN_USERNAME} ${HOME_DIR}/.env.sh

cp * ${HOME_DIR}

sudo apt-get install apt-transport-https lsb-release software-properties-common -y
AZ_REPO=$(lsb_release -cs)
echo "deb [arch=amd64] https://packages.microsoft.com/repos/azure-cli/ $AZ_REPO main" | \
    sudo tee /etc/apt/sources.list.d/azure-cli.list

sudo apt-key --keyring /etc/apt/trusted.gpg.d/Microsoft.gpg adv \
     --keyserver packages.microsoft.com \
     --recv-keys BC528686B50D79E339D3721CEB3E94ADBE1229CF

sudo apt-get update

sudo apt-get install azure-cli && sudo apt --yes install unzip 

wget -O terraform.zip https://releases.hashicorp.com/terraform/0.11.8/terraform_0.11.8_linux_amd64.zip && \
  unzip terraform.zip && \
  sudo mv terraform /usr/local/bin

wget -O om https://github.com/pivotal-cf/om/releases/download/0.48.0/om-linux && \
  chmod +x om && \
  sudo mv om /usr/local/bin/

wget -O bosh https://s3.amazonaws.com/bosh-cli-artifacts/bosh-cli-5.3.1-linux-amd64 && \
  chmod +x bosh && \
  sudo mv bosh /usr/local/bin/

wget -O /tmp/bbr.tar https://github.com/cloudfoundry-incubator/bosh-backup-and-restore/releases/download/v1.2.8/bbr-1.2.8.tar && \
  tar xvC /tmp/ -f /tmp/bbr.tar && \
  sudo mv /tmp/releases/bbr /usr/local/bin/
# get pivnet UAA TOKEN

cd ${HOME_DIR}

#  FAKING TERRAFORM DOWNLOAD FOR PKS
PRODUCT_SLUG="elastic-runtime"
RELEASE_ID="259105"
#


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
sudo -S -u ubuntu unzip ${FILENAME}
cd ./pivotal-cf-terraforming-azure-*/
cd terraforming-pas

 # preparation work for terraform
cat << EOF > terraform.tfvars
client_id             = "${AZURE_CLIENT_ID}"
client_secret         = "${AZURE_CLIENT_SECRET}"
subscription_id       = "${AZURE_SUBSCRIPTION_ID}"
tenant_id             = "${AZURE_TENANT_ID}"
env_name              = "${ENV_NAME}"
env_short_name        = "${ENV_SHORT_NAME}"
ops_manager_image_uri = "${OPS_MANAGER_IMAGE_URI}"
location              = "${LOCATION}"
dns_suffix            = "${PKS_DOMAIN_NAME}"
dns_subdomain         = "${PKS_SUBDOMAIN_NAME}"
ops_manager_private_ip = "${NET_16_BIT_MASK}.8.4"
pcf_infrastructure_subnet = "${NET_16_BIT_MASK}.8.0/26"
pcf_pas_subnet = "${NET_16_BIT_MASK}.0.0/22"
pcf_services_subnet = "${NET_16_BIT_MASK}.4.0/22"
pcf_virtual_network_address_space = ["${NET_16_BIT_MASK}.0.0/16"]
EOF


chmod 755 terraform.tfvars
chown ${ADMIN_USERNAME}.${ADMIN_USERNAME} terraform.tfvars
sudo -S -u ubuntu terraform init
sudo -S -u ubuntu terraform plan -out=plan
retryop "sudo -S -u ubuntu terraform apply -auto-approve" 3 1
END_BASE_DEPLOY_TIME=$(date)
echo ${END_BASE_DEPLOY_TIME} end base deployment
$(cat <<-EOF >> ${HOME_DIR}/.env.sh
END_BASE_DEPLOY_TIME="${END_BASE_DEPLOY_TIME}"
EOF
)

sudo -S -u ubuntu ${HOME_DIR}/om_init.sh

if [ "${PKS_AUTOPILOT}" = "TRUE" ]; then
    sudo -S -u ubuntu ${HOME_DIR}/create_certs.sh
    sudo -S -u ubuntu ${HOME_DIR}/deploy_pks.sh
fi
