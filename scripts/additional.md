# additional assumptions

## uaac client

```bash
sudo apt-get install ruby ruby-dev gcc libffi-dev make build-essential -y
# get pivnet UAA TOKEN
gem install cf-uaac
```



properties.pks_uaa_management_admin_client
uaac target api.${PKS_SUBDOMAIN_NAME}.${PKS_DOMAIN_NAME}:8443 --skip-ssl-validation
uaac token client get admin -s ADMIN-CLIENT-SECRET
uaac user add bottk --emails kbott@pivotal.io -p Breda1208
uaac member add pks.clusters.admin bottk

pks login -a api.pksazuredev.labbuildr.com -u bottk --skip-ssl-validation

```bash
uaac target ${PKS_OPSMAN_FQDN}/uaa --skip-ssl-validation
uaac token owner get opsman "${PKS_OPSMAN_USERNAME}" -s "" -p ${PIVNET_UAA_TOKEN}
APITOKEN=$(uaac contexts | grep "$OPSMAN_IP" -A6 | grep access_token | cut -d ':' -f  2 | cut -d ' ' -f 2)
```