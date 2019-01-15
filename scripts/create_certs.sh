source ~/.env.sh
cd ${HOME_DIR}
git clone https://github.com/Neilpang/acme.sh.git ./acme.sh

export AZUREDNS_SUBSCRIPTIONID=${AZURE_SUBSCRIPTION_ID}
export AZUREDNS_TENANTID=${AZURE_TENANT_ID}
export AZUREDNS_APPID=${AZURE_CLIENT_ID}
export AZUREDNS_CLIENTSECRET=${AZURE_CLIENT_SECRET}
DOMAIN="${PKS_SUBDOMAIN_NAME}.${PKS_DOMAIN_NAME}"
./acme.sh/acme.sh --issue \
 --dns dns_azure \
 --dnssleep 10 \
 --force \
 --debug \
 -d ${DOMAIN} \
 -d *.sys.${DOMAIN} \
 -d *.apps.${DOMAIN} \
 -d *.login.sys.${DOMAIN} \
 -d *.uaa.sys.${DOMAIN} \
 -d *.pks.${DOMAIN}


