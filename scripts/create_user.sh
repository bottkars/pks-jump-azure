#!/usr/bin/env bash
source .env.sh
MYSELF=$(basename $0)
mkdir -p ${LOG_DIR}/
exec &> >(tee -a "${LOG_DIR}/${MYSELF}.$(date '+%Y-%m-%d-%H').log")
exec 2>&1
export OM_TARGET=${PCF_OPSMAN_FQDN}
export OM_USERNAME=${PCF_OPSMAN_USERNAME}
export OM_PASSWORD="${PIVNET_UAA_TOKEN}"
export $( \
  om \
    --skip-ssl-validation \
    curl \
      --silent \
      --path /api/v0/deployed/director/credentials/bosh_commandline_credentials | \
        jq --raw-output '.credential' \
)

sudo mkdir -p /var/tempest/workspaces/default

sudo sh -c \
  "om \
    --skip-ssl-validation \
    --target ${PCF_OPSMAN_FQDN} \
    --username ${PCF_OPSMAN_USERNAME} \
    --password ${PIVNET_UAA_TOKEN} \
    curl \
      --silent \
      --path "/api/v0/security/root_ca_certificate" |
        jq --raw-output '.root_ca_certificate_pem' \
          > /var/tempest/workspaces/default/root_ca_certificate"

PCF_PKS_GUID=$( \
  om --env "${HOME_DIR}/om_${ENV_NAME}.env"  \
    curl \
      --silent \
      --path /api/v0/deployed/products | \
        jq --raw-output '.[] | select(.type=="pivotal-container-service") | .guid' \
)

PCF_PKS_UAA_MANAGEMENT_PASSWORD=$( \
  om --env "${HOME_DIR}/om_${ENV_NAME}.env"  \
    curl \
      --silent \
      --path /api/v0/deployed/products/${PCF_PKS_GUID}/credentials/.properties.pks_uaa_management_admin_client | \
        jq --raw-output '.credential.value.secret' \
)   

uaac target api.${PKS_SUBDOMAIN_NAME}.${PKS_DOMAIN_NAME}:8443 --skip-ssl-validation
uaac token client get admin -s ${PCF_PKS_UAA_MANAGEMENT_PASSWORD}

uaac user add k8sadmin --emails ${PKS_NOTIFICATIONS_EMAIL} -p ${PIVNET_UAA_TOKEN}
uaac member add pks.clusters.admin k8sadmin



