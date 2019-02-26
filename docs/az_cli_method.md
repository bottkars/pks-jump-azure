# AZ CLI Based installation Method

create an .env file using the [example](.env.example)  
see [parameters and variables](#parameters-and-variables) for details.  

source the env file  
```bash
source .env
```

## start the deployment

there are multiple deployment options, using az cli, powershell, from variables/parameters or from parameter file
use  
[deployment using default parameters](#using-default-parameters)
or  
[deployment using customized parameters](#using-customized-parameters)  

## using default parameters

### validate using default parameters

if not already done,  
source your [.env file](.env.example)

```bash
source .env
```

if not already done,  
create an ssh keypair for the environment  

```bash
ssh-keygen -t rsa -f ~/${JUMPBOX_NAME} -C ${ADMIN_USERNAME}
```

deployment using the default parameters only passes a minimum required parameters to the az command. all other values are set to their default.

```bash
az group create --name ${JUMPBOX_RG} --location ${AZURE_REGION}
az group deployment create --resource-group ${JUMPBOX_RG} \
    --template-uri https://raw.githubusercontent.com/bottkars/pks-jump-azure/${BRANCH}/azuredeploy.json \
    --parameters \
    sshKeyData="$(cat ~/${JUMPBOX_NAME}.pub)" \
    JumphostDNSLabelPrefix=${JUMPBOX_NAME} \
    clientSecret=${AZURE_CLIENT_SECRET} \
    clientID=${AZURE_CLIENT_ID} \
    tenantID=${AZURE_TENANT_ID} \
    subscriptionID=${AZURE_SUBSCRIPTION_ID} \
    pivnetToken=${PIVNET_UAA_TOKEN} \
    envShortName=${ENV_SHORT_NAME} \
    PKSDomainName=${PKS_DOMAIN_NAME} \
    PKSSubdomainName=${PKS_SUBDOMAIN_NAME}
```

### validate using customized parameters

```bash
az group create --name ${JUMPBOX_RG} --location ${AZURE_REGION}
az group deployment validate --resource-group ${JUMPBOX_RG} \
    --template-uri https://raw.githubusercontent.com/bottkars/pks-jump-azure/$BRANCH/azuredeploy.json \
    --parameters \
    adminUsername=${ADMIN_USERNAME} \
    sshKeyData="$(cat ~/${JUMPBOX_NAME}.pub)" \
    JumphostDNSLabelPrefix=${JUMPBOX_NAME} \
    clientSecret=${AZURE_CLIENT_SECRET} \
    clientID=${AZURE_CLIENT_ID} \
    tenantID=${AZURE_TENANT_ID} \
    subscriptionID=${AZURE_SUBSCRIPTION_ID} \
    pivnetToken=${PIVNET_UAA_TOKEN} \
    envName=${ENV_NAME} \
    envShortName=${ENV_SHORT_NAME} \
    opsmanImage=${OPS_MANAGER_IMAGE} \
    PKSDomainName=${PKS_DOMAIN_NAME} \
    PKSSubdomainName=${PKS_SUBDOMAIN_NAME} \
    opsmanUsername=${PCF_OPSMAN_USERNAME} \
    notificationsEmail=${PKS_NOTIFICATIONS_EMAIL} \
    PKSAutopilot=${PKS_AUTOPILOT} \
    PKSVersion=${PKS_VERSION} \
    net16bitmask=${NET_16_BIT_MASK} \
    useSelfCerts=${USE_SELF_CERTS} \
    _artifactsLocation=${ARTIFACTS_LOCATION} \
    vmSize=${VMSIZE} \
    opsmanImageRegion=${OPS_MANAGER_IMAGE_REGION}
```

installation using customized parameter set´s all required parameters from variables in your .env file

```bash
az group create --name ${JUMPBOX_RG} --location ${AZURE_REGION}
az group deployment create --resource-group ${JUMPBOX_RG} \
    --template-uri https://raw.githubusercontent.com/bottkars/pks-jump-azure/$BRANCH/azuredeploy.json \
    --parameters \
    adminUsername=${ADMIN_USERNAME} \
    sshKeyData="$(cat ~/${JUMPBOX_NAME}.pub)" \
    JumphostDNSLabelPrefix=${JUMPBOX_NAME} \
    clientSecret=${AZURE_CLIENT_SECRET} \
    clientID=${AZURE_CLIENT_ID} \
    tenantID=${AZURE_TENANT_ID} \
    subscriptionID=${AZURE_SUBSCRIPTION_ID} \
    pivnetToken=${PIVNET_UAA_TOKEN} \
    envName=${ENV_NAME} \
    envShortName=${ENV_SHORT_NAME} \
    opsmanImage=${OPS_MANAGER_IMAGE} \
    PKSDomainName=${PKS_DOMAIN_NAME} \
    PKSSubdomainName=${PKS_SUBDOMAIN_NAME} \
    opsmanUsername=${PCF_OPSMAN_USERNAME} \
    notificationsEmail=${PKS_NOTIFICATIONS_EMAIL} \
    PKSAutopilot=${PKS_AUTOPILOT} \
    PKSVersion=${PKS_VERSION} \
    net16bitmask=${NET_16_BIT_MASK} \
    useSelfCerts=${USE_SELF_CERTS} \
    _artifactsLocation=${ARTIFACTS_LOCATION} \
    vmSize=${VMSIZE} \
    opsmanImageRegion=${OPS_MANAGER_IMAGE_REGION}
```

## using a parameter file

tbd

## Parameters and variables

see this [table](/docs/parametes_and_vars.md) for Parameters and Variables

## debugging/ monitoring

watching the JUMPHost resource group creation  

```bash
watch az resource list --output table --resource-group ${JUMPBOX_RG}
```

watching the pks resource group creation  

```bash
watch az resource list --output table --resource-group ${ENV_NAME}
```