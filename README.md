# pks-jump-azure

pks-jump-azure creates an ubuntu based jumpbox to deploy Pivotal PKS (1.3 and above) on azure  

It will pave the infrastructure using Pivotal [terraforming-azure](https://github.com/pivotal-cf/terraforming-azure).  

PKS Operations Manager will be installed and configured using Pivotal [om cli](https://github.com/pivotal-cf/om).  
Optionally, PKS will be deployed using [om cli](https://github.com/pivotal-cf/om).  

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
**PIVNET_UAA_TOKEN**=*fave your pivnet refresh token*  
**ENV_NAME**=*pks* this name will be prefix for azure resources and you opsman hostname  
**ENV_SHORT_NAME**=*pkskb* will be used as prefix for storage accounts and other azure resources  
**OPS_MANAGER_IMAGE_URI**=*"https://opsmanagerwesteurope.blob.core.windows.net/images/ops-manager-2.4-build.131.vhd"* a 2.4 opsman image   
**PKS_DOMAIN_NAME**=*yourdomain.com*  
**PKS_SUBDOMAIN_NAME**=*yourpks*  
**PRODUCT_SLUG**=*elastic-runtime*  
**RELEASE_ID**=*259105*  
**PKS_NOTIFICATIONS_EMAIL**=*"user@example.com"*  
**PKS_OPSMAN_USERNAME**=*opsman*  
**PKS_AUTOPILOT**=*FALSE* Autoinstall PKS when set to true  
**PKS_VERSION**=*2.4.1* the version of PKS, must be 2.4.0 or greater
**16_BIT_MASK**=*10.12* the first 16 bit of Network

source the env file  
```bash
source .env
```

## create a ssh keypair for the admin user ( if not already done ) 

```bash
ssh-keygen -t rsa -f ~/opsman -C ${ADMIN_USERNAME}
```

## start the deployment

```bash
az group create --name ${JUMPBOX_RG} --location ${AZURE_REGION}
az group deployment create --resource-group ${JUMPBOX_RG} \
    --template-uri https://raw.githubusercontent.com/bottkars/pks-jump-azure/master/azuredeploy.json \
    --parameters \
    adminUsername=${ADMIN_USERNAME} \
    sshKeyData="$(cat ~/opsman.pub)" \
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

ssh into the Jumpbox  

```bash
 ssh -i ~/opsman ubuntu@${JUMPBOX_NAME}.${AZURE_REGION}.cloudapp.azure.com
```

tail the installation log  

```bash
tail -f ~/install.log
```

## cleanup

```bash
az group delete --name ${JUMPBOX_RG} --yes
az group delete --name ${ENV_NAME} --yes
ssh-keygen -R "${JUMPBOX_NAME}.${AZURE_REGION}.cloudapp.azure.com"
```