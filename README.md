# pks-jump-azure

<a href="https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2Fbottkars%2Fpks-jump-azure%2Fmaster%2Fazuredeploy.json" target="_blank">
    <img src="http://azuredeploy.net/deploybutton.png"/>
</a>
<a href="http://armviz.io/#/?load=https%3A%2F%2Fraw.githubusercontent.com%2Fbottkars%2Fpks-jump-azure%2Fmaster%2Fazuredeploy.json" target="_blank">
    <img src="http://armviz.io/visualizebutton.png"/>
</a>

<img src="https://docs.pivotal.io/images/pks.png" width="100"><img src="https://upload.wikimedia.org/wikipedia/commons/thumb/f/f1/Heart_coraz%C3%B3n.svg/800px-Heart_coraz%C3%B3n.svg.png" width="100">
<img src="https://docs.pivotal.io/images/icon_microsoft_azure@2x.png" width="100">

pks-jump-azure creates an ubuntu based jumpbox to auto-deploy Pivotal PKS (1.3 and above) on azure.  
it is based on an  [azure rm deployment template](./azuredeploy.json).  
<img src="https://user-images.githubusercontent.com/8255007/51332226-9e42fa80-1a7b-11e9-97ec-c91de80ace1c.png" width="400">

*Cloning or downloading the repo is not required, as the arm automation takes care for all scripts*
It will pave the infrastructure using Pivotal [terraforming-azure](https://github.com/pivotal-cf/terraforming-azure).  
Pivotal Operations Manager will be installed and configured using Pivotal [om cli](https://github.com/pivotal-cf/om).  
PKS and Harbor Tiles  will be deployed using [om cli](https://github.com/pivotal-cf/om).  
For that, the Tiles and required Stemcell(s) are downloaded automatically.

## Supported Versions

- OpsManager 2.5x and 2.6x <a href="https://network.pivotal.io/products/ops-manager"><img src="https://dtb5pzswcit1e.cloudfront.net/assets/images/product_logos/icon_pivotal_generic@2x.png" height="16" title="OpsManager 2.6x"> </a>
- Pivotal PKS 1.4.x <a href="https://network.pivotal.io/products/pivotal-container-service"><img src="https://dtb5pzswcit1e.cloudfront.net/assets/images/product_logos/icon_pivotalcontainerservice@2x.png" height="16"> </a>
- Harbor >=1.7.3 <a href="https://network.pivotal.io/products/harbor-container-registry"><img src="https://dtb5pzswcit1e.cloudfront.net/assets/images/product_logos/icon_vmware_harbor@2x.png" height="16" title="Harbor"> </a>
- Greenplum for Kubernetes >= 0.8.x <a href="https://network.pivotal.io/products/greenplum-for-kubernetes/"><img src="https://dtb5pzswcit1e.cloudfront.net/assets/images/product_logos/icon_gpdb@2x.png" height="16" Title = "Greenplum for Kubernetes"> </a>

## features

- automated opsman deployment and configuration
- pks infrastructure paving
- autopilot for deploying pks
- certificate generation using selfsigned or let´s encrypt [certificates](#certificates)
- dns registration of api loadbalancer ip
- network peering from jumphost to pks networks
- installation of cf-uaac, bosh cli
- dns configuration and check
- creation of public lb and dns a records for k8s clusters
- [script for additional k8s clusters](docs/create_cluster.md)
- load balancer rules for uaa and api access

## requirements

- a Azure Key Vault hosting all credentials / secrets required
- service principal, needs to have owner rights on subscription in order to create custom roles and Managed Identities
- a [pivotal network account ( pivnet )](network.pivotal.io) and a UAA access token

## usage

there are are multiple ways to deploy the ARM template. we will describe [Azure Portal Template based](#installation-using-template-deployment-preferred-for-first-time-users) and az cli based Method  

### create a ssh keypair for the admin user ( if not already done )

both methods require an SSH Keypair

```bash
ssh-keygen -t rsa -f ~/${JUMPBOX_NAME} -C ${ADMIN_USERNAME}
```

### Create and Populate an  Azure Key Vault

```bash
## Set temporary Variables
PIVNET_UAA_TOKEN=<your pivnet refresh token>
SERVICE_PRINCIPAL=$(az ad sp create-for-rbac --name ServicePrincipalforPKS --output json)
## SET the Following Secrets from the temporary Variables
az keyvault secret set --vault-name ${AZURE_VAULT} \
--name "AZURECLIENTID" --value $(echo $SERVICE_PRINCIPAL | jq -r .appId) --output none
az keyvault secret set --vault-name ${AZURE_VAULT} \
--name "AZURETENANTID" --value $(echo $SERVICE_PRINCIPAL | jq -r .tenant) --output none
az keyvault secret set --vault-name ${AZURE_VAULT} \
--name "AZURECLIENTSECRET" --value $(echo $SERVICE_PRINCIPAL | jq -r .password) --output none
az keyvault secret set --vault-name ${AZURE_VAULT} \
--name "PIVNETUAATOKEN" --value ${PIVNET_UAA_TOKEN} --output none
## unset the temporary variables
unset SERVICE_PRINCIPAL
```

### installation using Template Deployment (Preferred for First Time Users)

1. use the "deploy to Azure Button" to start a Template Deployment
<a href="https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2Fbottkars%2Fpks-jump-azure%2Fmaster%2Fazuredeploy.json" target="_blank">
    <img src="http://azuredeploy.net/deploybutton.png"/>
</a>

2. fill in all required Parameters ( marked with a red Star )
![image](https://user-images.githubusercontent.com/8255007/53296940-f0fb9900-3815-11e9-9404-de801064187a.png)
3. when done, click *Purchase*.

### Installation using az cli ( for Advanced Users)

see this [Document](docs/az_cli_method.md) for installation using AZ CLI

## What´s next

### Monitoring the deployment

When the ARM Deployment is finished, the Post Deployment jobs start

Monitor your Deployment using [debugging section](#debugging-monitoring)

### after the deployment

When the Deployment has finished, continue to
[getting started after deployment](./docs/initial_tasks.md)

the deployment might pause after opsmanager deployment, if your  opsmanager  fqdn is not resolvable  
the log file will, at this stage, show the Azure Name Servers that need to be added to your DNS NS Record  

![image](https://user-images.githubusercontent.com/8255007/51382000-ed3d6e00-1b15-11e9-8318-04c9f0993a1d.png)  
once fixed, the deployment will continue.

### Updating the deployment

a helper script is available to update the deployment
this can be

- script updates
- template updates for new versions

Simply run

```bash
wget -O - https://raw.githubusercontent.com/bottkars/pks-jump-azure/master/scripts/update.sh | bash
```

## debugging-monitoring

ssh into the Jumpbox  

```bash
 ssh -i ~/${JUMPBOX_NAME} ${ADMIN_USERNAME}@${JUMPBOX_NAME}.${AZURE_REGION}.cloudapp.azure.com
```

tail the installation log  

```bash
tail -f ~/install.log
```

### cleanup

Simply delete the Resource Groups
if using the Advances method, you may use:

```bash
az group delete --name ${JUMPBOX_RG} --yes
az group delete --name ${ENV_NAME} --yes
ssh-keygen -R "${JUMPBOX_NAME}.${AZURE_REGION}.cloudapp.azure.com"
az role definition delete --name ${AZURE_SUBSCRIPTION_ID}-${ENV_NAME}-pks-worker-role
az role definition delete --name ${AZURE_SUBSCRIPTION_ID}-${ENV_NAME}-pks-master-role
```

## Advanced tasks

see [advanced tasks](docs/advanced.md) that can make your life easy  
