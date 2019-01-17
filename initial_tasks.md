# initial tasks after deployment
![image](https://user-images.githubusercontent.com/8255007/51299845-0ec12b80-1a2a-11e9-91ac-eedd39687b2f.png)


## configure uaac
to configureb the PKS User Logins, we need to use the UAAC Admin client to generate credentials and assign user rights. 
the cf-uaac package is already installed on the Jumphost

### ssh into the Jumpbox  

```bash
 ssh -i ~/${JUMPBOX_NAME} ubuntu@${JUMPBOX_NAME}.${AZURE_REGION}.cloudapp.azure.com
```

### connect to uaac api endpoint

```bash
uaac target api.${PKS_SUBDOMAIN_NAME}.${PKS_DOMAIN_NAME}:8443 --skip-ssl-validation
```

sign in to uaac using the PKS UAA Management Admin Client Secret.  
You will get the secrets from the credentials tab in the PKS Tile:

<img src="https://user-images.githubusercontent.com/8255007/51299444-ce14e280-1a28-11e9-8628-1c9a6c8c5c16.png" width="400">

## create your first cluster
tbd: create an external lb for master
from a host with PKS CLI, login with the newly created Useraccount:

```bash
pks create-cluster k8s1 -e <external ip of lb>  -n 3 -p small --json
```
![image](https://user-images.githubusercontent.com/8255007/51299130-978a9800-1a27-11e9-9da9-84887c6e08f6.png)

## create you bosh environment from jumphost

```bash
source ~/.env.sh
export OM_TARGET=${PKS_OPSMAN_FQDN}
export OM_USERNAME=${PKS_OPSMAN_USERNAME}
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
    --target ${PKS_OPSMAN_FQDN} \
    --username ${PKS_OPSMAN_USERNAME} \
    --password ${PIVNET_UAA_TOKEN} \
    curl \
      --silent \
      --path "/api/v0/security/root_ca_certificate" |
        jq --raw-output '.root_ca_certificate_pem' \
          > /var/tempest/workspaces/default/root_ca_certificate"
```

## monitor creation from bosh

```bash
bosh deployments
```
![image](https://user-images.githubusercontent.com/8255007/51325284-e3136500-1a6c-11e9-993a-8e5afe31c150.png)

```bash
bosh -d bosh -d service-instance_19047a14-5c09-4837-92c2-e9144f218ca7 vms --details
```
![image](https://user-images.githubusercontent.com/8255007/51325297-eb6ba000-1a6c-11e9-8a9e-62456cc7fb0b.png)


