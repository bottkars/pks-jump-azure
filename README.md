# pks-jump-azure

pks-jump-azure creates an ubuntu based jumpbox to deploy Pivotal PKS (1.3 and above) on azure.  
it is based ojn a deployment azure deployment template.

Cloning or downloading the repo is not required, as the arm automation takes care for all scripts.  

It will pave the infrastructure using Pivotal [terraforming-azure](https://github.com/pivotal-cf/terraforming-azure).  
Pivotal Operations Manager will be installed and configured using Pivotal [om cli](https://github.com/pivotal-cf/om).  
Optionally, PKS will be deployed using [om cli](https://github.com/pivotal-cf/om).  
For that, the Tile and required Stemcell is downloaded automatically.
## requirements

- service principal needs to have owner rights on subscription in order to create custom roles
- a [pivotal network account ( pivnet )](network.pivotal.io) and access token

## usage  

create an .env file using the .env.example  
the .env vile requires the following variables to be set:  

**IAAS**=*azure* the environment, azure
**JUMPBOX_RG**=*JUMPBOX* ,the name of the ressource group for the JumpBox  
**JUMPBOX_NAME**=*pksjumpbox* ,the JumpBox hostname  
**ADMIN_USERNAME**=*ubuntu*  
**AZURE_CLIENT_ID**=*fake your azure client id*  
**AZURE_CLIENT_SECRET**=*fake your azure client secret*  
**AZURE_REGION**=*westeurope*  
**AZURE_SUBSCRIPTION_ID**=*fake your azure subscription id*  
**AZURE_TENANT_ID**=*fake your azure tenant*  
**PIVNET_UAA_TOKEN**=*fave your pivnet access token*  
**ENV_NAME**=*pks* this name will be prefix for azure resources and you opsman hostname  
**ENV_SHORT_NAME**=*pkskb* will be used as prefix for storage accounts and other azure resources  
**OPS_MANAGER_IMAGE_URI**=*"https://opsmanagerwesteurope.blob.core.windows.net/images/ops-manager-2.4-build.131.vhd"* a 2.4 opsman image   
**PKS_DOMAIN_NAME**=*yourdomain.com*  
**PKS_SUBDOMAIN_NAME**=*yourpks*  
**PRODUCT_SLUG**=*elastic-runtime*  
**RELEASE_ID**=*275389*  
**PKS_NOTIFICATIONS_EMAIL**=*"user@example.com"*  
**PKS_OPSMAN_USERNAME**=*opsman*  
**PKS_AUTOPILOT**=*FALSE* Autoinstall PKS when set to true  
**PKS_VERSION**=*1.3.0-RC2* the version of PKS, must be 1.3.0-RC2 or greater
**16_BIT_MASK**=*10.12* the first 16 bit of Network

source the env file  
```bash
source .env
```

## create a ssh keypair for the admin user ( if not already done )

```bash
ssh-keygen -t rsa -f ~/${JUMPBOX_NAME} -C ${ADMIN_USERNAME}
```

## start the deployment

```bash
az group create --name ${JUMPBOX_RG} --location ${AZURE_REGION}
az group deployment create --resource-group ${JUMPBOX_RG} \
    --template-uri https://raw.githubusercontent.com/bottkars/pks-jump-azure/master/azuredeploy.json \
    --parameters \
    adminUsername=${ADMIN_USERNAME} \
    sshKeyData="$(cat ~/${JUMPBOX_NAME}.pub)" \
    dnsLabelPrefix=${JUMPBOX_NAME} \
    clientSecret=${AZURE_CLIENT_SECRET} \
    clientID=${AZURE_CLIENT_ID} \
    tenantID=${AZURE_TENANT_ID} \
    subscriptionID=${AZURE_SUBSCRIPTION_ID} \
    pivnetToken=${PIVNET_UAA_TOKEN} \
    env_name=${ENV_NAME} \
    env_short_name=${ENV_SHORT_NAME} \
    ops_manager_image_uri=${OPS_MANAGER_IMAGE_URI} \
    pks_domain_name=${PKS_DOMAIN_NAME} \
    pks_subdomain_name=${PKS_SUBDOMAIN_NAME} \
    opsmanUsername=${PKS_OPSMAN_USERNAME} \
    product_slug=${PRODUCT_SLUG} \
    release_id=${RELEASE_ID} \
    notificationsEmail=${PKS_NOTIFICATIONS_EMAIL} \
    pksAutopilot=${PKS_AUTOPILOT} \
    pksVersion=${PKS_VERSION} \
    net_16_bit_mask=${NET_16_BIT_MASK}
```

## debugging/ monitoring

watching the JUMPHost resource group creation  

```bash
watch az resource list --output table --resource-group ${JUMPBOX_RG}
```

watching the pks resource group creation  

```bash
watch az resource list --output table --resource-group ${ENV_NAME}
```

ssh into the Jumpbox  

```bash
 ssh -i ~/${JUMPBOX_NAME} ubuntu@${JUMPBOX_NAME}.${AZURE_REGION}.cloudapp.azure.com
```

tail the installation log  

```bash
tail -f ~/install.log
```

## ssh into the opsmanager vm

from the jumpbox, you can  

```bash
source .env.sh
ssh -i opsman ubuntu@${PKS_OPSMAN_FQDN}

bosh alias-env pks -e 10.0.8.11 --ca-cert /var/tempest/workspaces/default/root_ca_certificate

```

## cleanup

```bash
az group delete --name ${JUMPBOX_RG} --yes
az group delete --name ${ENV_NAME} --yes
ssh-keygen -R "${JUMPBOX_NAME}.${AZURE_REGION}.cloudapp.azure.com"
```
