#!/usr/bin/env bash
source ~/.env.sh
MYSELF=$(basename $0)
mkdir -p ${LOG_DIR}/
exec &> >(tee -a "${LOG_DIR}/${MYSELF}.$(date '+%Y-%m-%d-%H').log")
exec 2>&1
cd ${HOME_DIR}
git clone https://github.com/Neilpang/acme.sh.git ./acme.sh

METADATA=$(curl -s -H Metadata:true "http://169.254.169.254/metadata/instance/compute?api-version=2017-08-01")
TOKEN=$(curl 'http://169.254.169.254/metadata/identity/oauth2/token?api-version=2018-02-01&resource=https%3A%2F%2Fvault.azure.net' -s -H Metadata:true | jq -r .access_token)
export AZUREDNS_SUBSCRIPTIONID=$(curl -s -H Metadata:true "http://169.254.169.254/metadata/instance/compute?api-version=2017-08-01" | jq -r .subscriptionId)
export AZUREDNS_TENANTID=$(curl https://${AZURE_VAULT}.vault.azure.net/secrets/AZURETENANTID?api-version=2016-10-01 -s -H "Authorization: Bearer ${TOKEN}" | jq -r .value)
export AZUREDNS_APPID=$(curl https://${AZURE_VAULT}.vault.azure.net/secrets/AZURECLIENTID?api-version=2016-10-01 -s -H "Authorization: Bearer ${TOKEN}" | jq -r .value)
export AZUREDNS_CLIENTSECRET=$(curl https://${AZURE_VAULT}.vault.azure.net/secrets/AZURECLIENTSECRET?api-version=2016-10-01 -s -H "Authorization: Bearer ${TOKEN}" | jq -r .value)


DOMAIN="${PKS_SUBDOMAIN_NAME}.${PKS_DOMAIN_NAME}"
./acme.sh/acme.sh --issue \
 --dns dns_azure \
 --dnssleep 10 \
 --force \
 --debug \
 -d ${DOMAIN} \
 -d pcf.${DOMAIN} \
 -d harbor.${DOMAIN} \
 -d *.sys.${DOMAIN} \
 -d *.apps.${DOMAIN} \
 -d *.login.sys.${DOMAIN} \
 -d *.uaa.sys.${DOMAIN} \
 -d *.pks.${DOMAIN} \
 -d build-service.${DOMAIN}

cp ${HOME_DIR}/.acme.sh/${PKS_SUBDOMAIN_NAME}.${PKS_DOMAIN_NAME}/${PKS_SUBDOMAIN_NAME}.${PKS_DOMAIN_NAME}.key ${HOME_DIR}
cp ${HOME_DIR}/.acme.sh/${PKS_SUBDOMAIN_NAME}.${PKS_DOMAIN_NAME}/fullchain.cer ${HOME_DIR}
cp ${HOME_DIR}/.acme.sh/${PKS_SUBDOMAIN_NAME}.${PKS_DOMAIN_NAME}/ca.cer ${HOME_DIR}/${DOMAIN}.ca.crt