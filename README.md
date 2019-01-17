# pks-jump-azure

pks-jump-azure creates an ubuntu based jumpbox to deploy Pivotal PKS (1.3 and above) on azure.  
it is based on an deployment [azure rm deployment template](./azuredeploy.json).

Cloning or downloading the repo is not required, as the arm automation takes care for all scripts.  

It will pave the infrastructure using Pivotal [terraforming-azure](https://github.com/pivotal-cf/terraforming-azure).  
Pivotal Operations Manager will be installed and configured using Pivotal [om cli](https://github.com/pivotal-cf/om).  
Optionally, PKS will be deployed using [om cli](https://github.com/pivotal-cf/om).  
For that, the Tile and required Stemcell is downloaded automatically.

## requirements

- service principal needs to have owner rights on subscription in order to create custom roles and Managed Identities
- a [pivotal network account ( pivnet )](network.pivotal.io) and a UAA access token

## usage  

create an .env file using the .env.example  
see [parameters and variables](#parameters-and-variables) for details.  

source the env file  
```bash
source .env
```

## create a ssh keypair for the admin user ( if not already done )

```bash
ssh-keygen -t rsa -f ~/${JUMPBOX_NAME} -C ${ADMIN_USERNAME}
```

## start the deployment

there are multiple deployment options, using az cli, powershell, from variables/parameters or from parameter file

[deployment using default parameters](#using-default-parameters)
[deployment using customized parameters](#using-customized-parameters)

for debugging, see debugging section

### using default parameters

deployment using the default parameters only passes a minimum required parameters to the az command. all other values are set to their default.

```bash
az group create --name ${JUMPBOX_RG} --location ${AZURE_REGION}
az group deployment create --resource-group ${JUMPBOX_RG} \
    --template-uri https://raw.githubusercontent.com/bottkars/pks-jump-azure/master/azuredeploy.json \
    --parameters \
    sshKeyData="$(cat ~/${JUMPBOX_NAME}.pub)" \
    dnsLabelPrefix=${JUMPBOX_NAME} \
    clientSecret=${AZURE_CLIENT_SECRET} \
    clientID=${AZURE_CLIENT_ID} \
    tenantID=${AZURE_TENANT_ID} \
    subscriptionID=${AZURE_SUBSCRIPTION_ID} \
    pivnetToken=${PIVNET_UAA_TOKEN} \
    envShortName=${ENV_SHORT_NAME} \
    pksDomainName=${PKS_DOMAIN_NAME} \
    pksSubdomainName=${PKS_SUBDOMAIN_NAME} \
```

### using customized parameters

installation using customized parameter set´s all required parameters from variables in your .env file

```bash
az group create --name ${JUMPBOX_RG} --location ${AZURE_REGION}
az group deployment create --resource-group ${JUMPBOX_RG} \
    --template-uri https://raw.githubusercontent.com/bottkars/pks-jump-azure/master/azuredeploy.json \
    --parameters \
    sshKeyData="$(cat ~/${JUMPBOX_NAME}.pub)" \
    dnsLabelPrefix=${JUMPBOX_NAME} \
    clientSecret=${AZURE_CLIENT_SECRET} \
    clientID=${AZURE_CLIENT_ID} \
    tenantID=${AZURE_TENANT_ID} \
    subscriptionID=${AZURE_SUBSCRIPTION_ID} \
    pivnetToken=${PIVNET_UAA_TOKEN} \
    envName=${ENV_NAME} \
    envShortName=${ENV_SHORT_NAME} \
    opsmanImageUri=${OPS_MANAGER_IMAGE_URI} \
    pksDomainName=${PKS_DOMAIN_NAME} \
    pksSubdomainName=${PKS_SUBDOMAIN_NAME} \
    opsmanUsername=${PKS_OPSMAN_USERNAME} \
    notificationsEmail=${PKS_NOTIFICATIONS_EMAIL} \
    pksAutopilot=${PKS_AUTOPILOT} \
    pksVersion=${PKS_VERSION} \
    net16bitmask=${NET_16_BIT_MASK} \
    useSelfCerts=${USE_SELF_CERTS}

```

## using a parameter file

tbd

## parameters and variables

 variable  | parameter  | default value  | mandatory | description  
--:|---|---|---|---
 IAAS  |   |   |   |
 JUMPBOX_RG  |   |   | no, only to create RG/ Deployment  |
 JUMPBOX_NAME  |   |   | yes  |
 ADMIN_USERNAME  |   | ubuntu  | no  |
 AZURE_CLIENT_ID  |   |   |  yes |
 AZURE_CLIENT_SECRET |   |   | yes  |
 AZURE_REGION  |   | westeurope  | no  |
 AZURE_SUBSCRIPTION_ID  |   |   | yes  |
 AZURE_TENANT_ID   |   |   | yes  |
 PIVNET_UAA_TOKEN  |   |   | yes  |
 ENV_NAME  |   | pks  | no  |
 ENV_SHORT_NAME  |   |   |yes |
 OPS_MANAGER_IMAGE_URI  |   |   | no  |
 PKS_DOMAIN_NAME  |   |   | yes  |
 PKS_SUBDOMAIN_NAME  |   |   | yes  |
 PKS_VERSION  |   |1.3.0 |no|
 PKS_OPSMAN_USERNAME  |   | opsman  | no  |
 PKS_NOTIFICATIONS_EMAIL  |   | user@example.com  | no  |
 PKS_AUTOPILOT  |   |TRUE   |no   |
 NET_16_BIT_MASK  |   |   | no  |
 USE_SELF_CERTS  |   | true  | no  |
   |   |   |   |

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
